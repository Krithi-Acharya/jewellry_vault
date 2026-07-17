import prisma from '../config/database.js';

// --- DTO Mappers ---
const mapItemToDto = (item) => {
  return {
    id: item.ci_id,
    categoryId: item.ci_category_id,
    categoryName: item.item_categories?.itc_name || null,
    status: item.ci_status,
    isDeleted: item.ci_is_deleted,
    deletedAt: item.ci_deleted_at,
    images: item.closet_item_images?.map(img => img.cii_url) || [],
    attributes: item.closet_item_attributes || null,
  };
};

// --- Controllers ---

export const createItem = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    if (!userId) {
      return res.status(403).json({ success: false, message: 'User not synced in database.' });
    }

    const { categoryId, status } = req.body;

    const item = await prisma.closet_items.create({
      data: {
        ci_usr_id: userId,
        ci_category_id: categoryId,
        ci_status: status || 'ACTIVE',
      },
      include: {
        item_categories: true,
      }
    });

    res.status(201).json({
      success: true,
      data: mapItemToDto(item),
    });
  } catch (error) {
    console.error('Error creating item:', error);
    res.status(500).json({ success: false, message: 'Failed to create item' });
  }
};

export const getItems = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    if (!userId) return res.status(403).json({ success: false, message: 'Forbidden' });

    // Extract pagination, filtering, sorting
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    
    const categoryName = req.query.category; // e.g. "Ring"
    const status = req.query.status;
    const sortField = req.query.sort || 'ci_id'; // e.g., created_at (we don't have created_at on items yet, defaulting to id)
    const sortOrder = req.query.order === 'asc' ? 'asc' : 'desc';

    // Build Prisma Where Clause
    const where = {
      ci_usr_id: userId,
      ci_is_deleted: false, // Don't return soft deleted items
    };

    if (categoryName) {
      where.item_categories = { itc_name: { equals: categoryName, mode: 'insensitive' } };
    }
    
    if (status) {
      where.ci_status = { equals: status, mode: 'insensitive' };
    }

    const [items, total] = await Promise.all([
      prisma.closet_items.findMany({
        where,
        skip,
        take: limit,
        orderBy: {
          [sortField]: sortOrder,
        },
        include: {
          item_categories: true,
          closet_item_images: true,
        }
      }),
      prisma.closet_items.count({ where })
    ]);

    res.status(200).json({
      success: true,
      data: items.map(mapItemToDto),
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      }
    });
  } catch (error) {
    console.error('Error fetching items:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch items' });
  }
};

export const getItemById = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const itemId = parseInt(req.params.id);
    if (!userId) return res.status(403).json({ success: false, message: 'Forbidden' });

    const item = await prisma.closet_items.findUnique({
      where: { ci_id: itemId },
      include: {
        item_categories: true,
        closet_item_images: true,
        closet_item_attributes: true,
      }
    });

    if (!item || item.ci_usr_id !== userId || item.ci_is_deleted) {
      return res.status(404).json({ success: false, message: 'Item not found' });
    }

    res.status(200).json({
      success: true,
      data: mapItemToDto(item),
    });
  } catch (error) {
    console.error('Error fetching item:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch item' });
  }
};

export const updateItem = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const itemId = parseInt(req.params.id);
    if (!userId) return res.status(403).json({ success: false, message: 'Forbidden' });

    // Check ownership
    const existing = await prisma.closet_items.findUnique({
      where: { ci_id: itemId }
    });

    if (!existing || existing.ci_usr_id !== userId || existing.ci_is_deleted) {
      return res.status(404).json({ success: false, message: 'Item not found' });
    }

    const { categoryId, status } = req.body;

    const item = await prisma.closet_items.update({
      where: { ci_id: itemId },
      data: {
        ...(categoryId && { ci_category_id: categoryId }),
        ...(status && { ci_status: status }),
      },
      include: {
        item_categories: true,
      }
    });

    res.status(200).json({
      success: true,
      data: mapItemToDto(item),
    });
  } catch (error) {
    console.error('Error updating item:', error);
    res.status(500).json({ success: false, message: 'Failed to update item' });
  }
};

export const deleteItem = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const itemId = parseInt(req.params.id);
    if (!userId) return res.status(403).json({ success: false, message: 'Forbidden' });

    // Check ownership
    const existing = await prisma.closet_items.findUnique({
      where: { ci_id: itemId }
    });

    if (!existing || existing.ci_usr_id !== userId || existing.ci_is_deleted) {
      return res.status(404).json({ success: false, message: 'Item not found' });
    }

    // Soft Delete
    await prisma.closet_items.update({
      where: { ci_id: itemId },
      data: {
        ci_is_deleted: true,
        ci_deleted_at: new Date(),
      }
    });

    res.status(200).json({
      success: true,
      message: 'Item deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting item:', error);
    res.status(500).json({ success: false, message: 'Failed to delete item' });
  }
};
