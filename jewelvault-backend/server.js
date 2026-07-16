require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const db = require('./db'); // Importing your PostgreSQL connection

const app = express();
app.use(cors());
app.use(express.json());

// 1. Initialize Firebase Admin (v14 modular API)
const serviceAccount = require('./firebase-key.json');
const firebaseApp = initializeApp({
  credential: cert(serviceAccount)
});
const firebaseAuth = getAuth(firebaseApp);

// 2. THE BOUNCER (AuthN Middleware)
// Verifies the Firebase ID token AND makes sure a matching row exists in
// the `users` table. Since signup happens purely on the Flutter/Firebase
// side, this is the moment a "user" first becomes known to Postgres.
async function verifyToken(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No ID card provided. Access Denied.' });
  }

  const token = authHeader.split('Bearer ')[1];

  try {
    const decodedToken = await firebaseAuth.verifyIdToken(token);
    req.user = decodedToken; // Raw Firebase claims (uid, email, name, ...)

    // Auto-provision (or refresh) the user's row. ON CONFLICT makes this
    // safe to run on every request — first login creates the row, every
    // login after that just keeps the email in sync (role/status/username
    // set by an admin are left untouched).
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

    // Authorization gate: a suspended/inactive account should not be able
    // to use any protected route, even with a perfectly valid Firebase token.
    if (dbUser.usr_status === 'suspended' || dbUser.usr_status === 'inactive') {
      return res.status(403).json({ error: `Account is ${dbUser.usr_status}.` });
    }

    req.dbUserId = dbUser.usr_id;     // internal Postgres identity
    req.dbUserRole = dbUser.usr_role; // 'user' | 'admin'
    next();
  } catch (error) {
    console.error('Auth error:', error.message);
    return res.status(401).json({ error: 'Fake or expired ID card.' });
  }
}

// Authorization middleware for admin-only routes. Use AFTER verifyToken,
// e.g.: app.get('/api/admin/whatever', verifyToken, requireAdmin, handler)
function requireAdmin(req, res, next) {
  if (req.dbUserRole !== 'admin') {
    return res.status(403).json({ error: 'Forbidden. Admins only.' });
  }
  next();
}

// item_categories is a lookup table (itc_name UNIQUE). This resolves a
// category name to its id, creating the row the first time it's seen —
// so the Flutter app can keep sending plain strings like "Garment" or
// "Jewelry" without needing to know about ids at all.
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

// Turns a closet_items row (joined with its category name) into the shape
// the Flutter app expects.
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
  };
}

// Shared SELECT that joins in the category name every route needs.
const CLOSET_SELECT = `
  SELECT ci.*, itc.itc_name
  FROM closet_items ci
  JOIN item_categories itc ON itc.itc_id = ci.ci_category_id
`;

// 3. DASHBOARD ROUTE (any logged-in user)
app.get('/api/dashboard', verifyToken, async (req, res) => {
  try {
    const userQuery = await db.query('SELECT usr_email FROM users WHERE usr_id = $1', [req.dbUserId]);
    if (userQuery.rows.length === 0) {
      return res.status(404).json({ error: 'User profile not found.' });
    }
    res.json({ message: `Welcome to your dashboard, ${userQuery.rows[0].usr_email}!` });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error while fetching dashboard.' });
  }
});

// 4. CLOSET ITEM ROUTES — every route is scoped to req.dbUserId so users
// can only ever see or touch their own items.

// GET /api/closet — list everything in the logged-in user's vault
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

// POST /api/closet — catalog a new item
app.post('/api/closet', verifyToken, async (req, res) => {
  const { title, category, brand, color, season, icon, matchScore } = req.body;

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

    const fullRow = await db.query(`${CLOSET_SELECT} WHERE ci.ci_id = $1`, [insertResult.rows[0].ci_id]);
    res.status(201).json(serializeItem(fullRow.rows[0]));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to create closet item.' });
  }
});

// PATCH /api/closet/:id — update fields on an item (favorite toggle, wear count, etc.)
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

// DELETE /api/closet/:id — remove an item from the vault
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