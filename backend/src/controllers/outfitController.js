import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const storePath = path.join(__dirname, '../../public/uploads/outfits_store.json');

function loadOutfitsStore() {
  try {
    if (fs.existsSync(storePath)) {
      const data = fs.readFileSync(storePath, 'utf8');
      return JSON.parse(data);
    }
  } catch (e) {
    console.error('Error reading outfits store:', e);
  }
  return [];
}

function saveOutfitsStore(outfits) {
  try {
    const dir = path.dirname(storePath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(storePath, JSON.stringify(outfits, null, 2), 'utf8');
  } catch (e) {
    console.error('Error saving outfits store:', e);
  }
}

/**
 * GET /api/v1/outfits
 * Fetch saved outfits for logged-in user
 */
export const getOutfits = async (req, res) => {
  try {
    const userId = req.user?.uid || 'default';
    const allOutfits = loadOutfitsStore();
    const userOutfits = allOutfits.filter(o => o.userId === userId || o.userId === 'default');
    return res.status(200).json(userOutfits);
  } catch (error) {
    console.error('Error fetching outfits:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * POST /api/v1/outfits
 * Save an outfit from closet item IDs
 */
export const createOutfit = async (req, res) => {
  try {
    const userId = req.user?.uid || 'default';
    const { itemIds, name, season, occasion, tags } = req.body;
    
    const newOutfit = {
      id: `outfit_${Date.now()}_${Math.round(Math.random() * 1000)}`,
      userId,
      itemIds: itemIds || [],
      name: name || 'Untitled Look',
      season: season || 'All',
      occasion: occasion || 'Casual',
      tags: tags || [],
      createdAt: new Date().toISOString(),
      isFavorite: false,
    };

    const allOutfits = loadOutfitsStore();
    allOutfits.unshift(newOutfit);
    saveOutfitsStore(allOutfits);

    return res.status(201).json(newOutfit);
  } catch (error) {
    console.error('Error creating outfit:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * POST /api/v1/outfits/photo
 * Save an outfit from uploaded canvas screenshot/photo
 */
export const createOutfitFromPhoto = async (req, res) => {
  try {
    const userId = req.user?.uid || 'default';
    let imageUrl = null;

    if (req.file) {
      imageUrl = `/uploads/${req.file.filename}`;
    }

    const newOutfit = {
      id: `outfit_${Date.now()}_${Math.round(Math.random() * 1000)}`,
      userId,
      imageUrl,
      createdAt: new Date().toISOString(),
      isFavorite: false,
    };

    const allOutfits = loadOutfitsStore();
    allOutfits.unshift(newOutfit);
    saveOutfitsStore(allOutfits);

    return res.status(201).json(newOutfit);
  } catch (error) {
    console.error('Error creating outfit from photo:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * DELETE /api/v1/outfits/:id
 * Delete a saved outfit by ID
 */
export const deleteOutfit = async (req, res) => {
  try {
    const { id } = req.params;
    let allOutfits = loadOutfitsStore();
    allOutfits = allOutfits.filter(o => o.id !== id);
    saveOutfitsStore(allOutfits);
    return res.status(204).send();
  } catch (error) {
    console.error('Error deleting outfit:', error);
    return res.status(500).json({ success: false, message: error.message });
  }
};
