require('dotenv').config();
const express = require('express');
const cors = require('cors');
const multer = require('multer');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const db = require('./db'); // Importing your PostgreSQL connection

const app = express();
app.use(cors());
// Default express.json() caps request bodies at 100kb — way too small
// for a base64-encoded photo (which runs ~33% larger than the raw file).
// 12mb comfortably covers a compressed phone photo.
app.use(express.json({ limit: '12mb' }));

// multer keeps the uploaded photo in memory as a Buffer (no temp files on
// disk) so /api/closet/analyze can base64-encode it straight away. 10MB
// cap is generous for a phone photo while blocking anything absurd.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
});

// Every response here is dynamic, per-user data — never let the browser
// (or any intermediate cache) serve a stale 304 for it. Without this,
// Chrome will sometimes revalidate a GET and return 304 Not Modified,
// which trips up clients that only treat 200 as success.
app.use((req, res, next) => {
  res.set('Cache-Control', 'no-store');
  next();
});

// 1. Initialize Firebase Admin (v14 modular API)
const serviceAccount = require('./firebase-key.json');
const firebaseApp = initializeApp({
  credential: cert(serviceAccount)
});
const firebaseAuth = getAuth(firebaseApp);

// 2. THE BOUNCER (AuthN Middleware)
async function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No ID card provided. Access Denied.' });
  }

  const token = authHeader.split('Bearer ')[1];

  try {
    const decodedToken = await firebaseAuth.verifyIdToken(token);
    req.user = decodedToken;

    const result = await db.query(
      `INSERT INTO users (usr_firebase_uid, usr_email, usr_status)
       VALUES ($1, $2, $3)
       ON CONFLICT (usr_firebase_uid)
       DO UPDATE SET usr_email = EXCLUDED.usr_email
       RETURNING usr_id, usr_role, usr_status`,
      [
        decodedToken.uid,
        decodedToken.email || '',
        decodedToken.email_verified ? 'active' : 'pending_verification',
      ]
    );

    const dbUser = result.rows[0];

    if (dbUser.usr_status === 'suspended' || dbUser.usr_status === 'inactive') {
      return res.status(403).json({ error: `Account is ${dbUser.usr_status}.` });
    }

    req.dbUserId = dbUser.usr_id;
    req.dbUserRole = dbUser.usr_role;
    next();
  } catch (error) {
    console.error('Auth error:', error.message);
    return res.status(401).json({ error: 'Fake or expired ID card.' });
  }
}

function requireAdmin(req, res, next) {
  if (req.dbUserRole !== 'admin') {
    return res.status(403).json({ error: 'Forbidden. Admins only.' });
  }
  next();
}

async function getOrCreateCategoryId(name) {
  const categoryName = (name || 'Garment').trim();
  const result = await db.query(
    `INSERT INTO item_categories (itc_name)
     VALUES ($1)
     ON CONFLICT (itc_name) DO UPDATE SET itc_name = EXCLUDED.itc_name
     RETURNING itc_id`,
    [categoryName]
  );
  return result.rows[0].itc_id;
}

function serializeItem(row) {
  return {
    id: String(row.ci_id),
    title: row.ci_title,
    category: row.itc_name,
    brand: row.ci_brand,
    color: row.ci_color,
    season: row.ci_season,
    wornCount: row.ci_worn_count,
    matchScore: Number(row.ci_match_score),
    isFavorite: row.ci_is_favorite,
    icon: row.ci_icon,
    // Holds a base64 data URI (data:image/jpeg;base64,...) rather than a
    // real external URL — see closet_item_images.cii_image_url.
    imageUrl: row.cii_image_url || null,
  };
}

const CLOSET_SELECT = `
  SELECT ci.*, itc.itc_name, cii.cii_image_url
  FROM closet_items ci
  JOIN item_categories itc ON itc.itc_id = ci.ci_category_id
  LEFT JOIN closet_item_images cii
    ON cii.cii_ci_id = ci.ci_id AND cii.cii_is_primary = true
`;

app.get('/api/dashboard', verifyToken, async (req, res) => {
  try {
    const userQuery = await db.query(
      'SELECT usr_email, usr_display_name FROM users WHERE usr_id = $1',
      [req.dbUserId]
    );
    if (userQuery.rows.length === 0) {
      return res.status(404).json({ error: 'User profile not found.' });
    }
    const { usr_email, usr_display_name } = userQuery.rows[0];
    // Fall back to the email's local part if the user hasn't synced a
    // display name yet (e.g. account created before this feature shipped).
    const name = usr_display_name || usr_email.split('@')[0];
    res.json({ username: name, message: `Welcome to your dashboard, ${name}!` });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error while fetching dashboard.' });
  }
});

// POST /api/auth/sync-user — called once right after Firebase signup to
// save the display name the user typed in the signup form. Auth already
// happened via verifyToken (which also auto-provisions the users row), so
// this just fills in the one field Firebase itself doesn't know about.
app.post('/api/auth/sync-user', verifyToken, async (req, res) => {
  const { displayName } = req.body;

  if (!displayName || !displayName.trim()) {
    return res.status(400).json({ error: 'displayName is required.' });
  }

  try {
    const result = await db.query(
      `UPDATE users SET usr_display_name = $1 WHERE usr_id = $2 RETURNING usr_display_name`,
      [displayName.trim(), req.dbUserId]
    );
    res.json({ username: result.rows[0].usr_display_name });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to sync user profile.' });
  }
});

app.get('/api/closet', verifyToken, async (req, res) => {
  try {
    const result = await db.query(
      `${CLOSET_SELECT}
       WHERE ci.ci_usr_id = $1 AND ci.ci_status != 'deleted'
       ORDER BY ci.ci_created_at DESC`,
      [req.dbUserId]
    );
    res.json(result.rows.map(serializeItem));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch closet items.' });
  }
});

app.post('/api/closet', verifyToken, async (req, res) => {
  const { title, category, brand, color, season, icon, matchScore, imageUrl } = req.body;

  if (!title || !category) {
    return res.status(400).json({ error: 'title and category are required.' });
  }

  try {
    const categoryId = await getOrCreateCategoryId(category);

    const insertResult = await db.query(
      `INSERT INTO closet_items
         (ci_usr_id, ci_category_id, ci_title, ci_brand, ci_color, ci_season, ci_icon, ci_match_score)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING ci_id`,
      [
        req.dbUserId,
        categoryId,
        title,
        brand || 'Unknown',
        color || '—',
        season || 'All',
        icon || 'checkroom_outlined',
        matchScore || 80,
      ]
    );
    const newItemId = insertResult.rows[0].ci_id;

    // imageUrl here is actually a base64 data URI (see closet_item_images
    // comment above) produced by /api/closet/analyze and passed straight
    // through by the app once the person taps "Save to Vault".
    if (imageUrl) {
      await db.query(
        `INSERT INTO closet_item_images (cii_ci_id, cii_image_url, cii_is_primary)
         VALUES ($1, $2, true)`,
        [newItemId, imageUrl]
      );
    }

    const fullRow = await db.query(`${CLOSET_SELECT} WHERE ci.ci_id = $1`, [newItemId]);
    res.status(201).json(serializeItem(fullRow.rows[0]));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to create closet item.' });
  }
});

// POST /api/closet/analyze — accepts a multipart photo (field name "image")
// and returns the extracted item details the Flutter app shows on the
// "Detected Details" screen before saving. Nothing is written to the
// database here — the app calls POST /api/closet separately once the
// person taps "Save to Vault", passing this response straight through.
//
// The image itself is base64-encoded and handed back as a data URI in
// `imageUrl`; the app round-trips that same string to POST /api/closet,
// which is what actually persists it into closet_item_images.
//
// TODO: title/category/brand/color below are placeholders. Wire in the
// real pipeline here once it's ready:
//   1. Send the buffer to your Python OpenCV service for color + cropping
//   2. Send the (cleaned) image to your vision model for title/category/brand
//   3. Merge both results into the object returned below
app.post('/api/closet/analyze', verifyToken, upload.single('image'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'No image uploaded (expected field "image").' });
  }

  try {
    const mimeType = req.file.mimetype || 'image/jpeg';
    const base64 = req.file.buffer.toString('base64');
    const imageUrl = `data:${mimeType};base64,${base64}`;

    // Placeholder extraction until the Python/vision pipeline is wired in.
    res.json({
      imageUrl,
      title: 'Untitled Piece',
      category: 'Garment',
      brand: 'Unknown',
      color: '—',
      season: 'All',
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to analyze image.' });
  }
});

app.patch('/api/closet/:id', verifyToken, async (req, res) => {
  const { id } = req.params;
  const { isFavorite, wornCount, title, brand, color, season } = req.body;

  try {
    const updateResult = await db.query(
      `UPDATE closet_items
       SET ci_is_favorite = COALESCE($1, ci_is_favorite),
           ci_worn_count  = COALESCE($2, ci_worn_count),
           ci_title       = COALESCE($3, ci_title),
           ci_brand       = COALESCE($4, ci_brand),
           ci_color       = COALESCE($5, ci_color),
           ci_season      = COALESCE($6, ci_season)
       WHERE ci_id = $7 AND ci_usr_id = $8
       RETURNING ci_id`,
      [isFavorite, wornCount, title, brand, color, season, id, req.dbUserId]
    );

    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: 'Item not found.' });
    }

    const fullRow = await db.query(`${CLOSET_SELECT} WHERE ci.ci_id = $1`, [id]);
    res.json(serializeItem(fullRow.rows[0]));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update closet item.' });
  }
});

app.delete('/api/closet/:id', verifyToken, async (req, res) => {
  const { id } = req.params;
  try {
    const result = await db.query(
      'DELETE FROM closet_items WHERE ci_id = $1 AND ci_usr_id = $2 RETURNING ci_id',
      [id, req.dbUserId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Item not found.' });
    }
    res.status(204).send();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to delete closet item.' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Secure Backend running on port ${PORT}`));