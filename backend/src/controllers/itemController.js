import prisma from '../config/database.js';
import { mapAiAttributesToFlutter, mapAiColorsToFlutter, mapAiHistory, getPrimaryColorName } from '../utils/aiMetadataMapper.js';

// --- DTO Mappers ---
const mapItemToDto = (item) => {
  let badgeStatus = 'Processing';
  if (item.ci_status === 'ACTIVE') {
    const tags = item.closet_item_ai_tags?.ciaitag_tags || {};
    if (tags.is_edited) {
      badgeStatus = 'Edited';
    } else if ((tags.ai_attributes?.final_confidence || 1.0) < 0.70) {
      badgeStatus = 'Needs Review';
    } else {
      badgeStatus = 'Verified';
    }
  }

  const tags = item.closet_item_ai_tags?.ciaitag_tags || {};
  const aiAttributes = tags.ai_attributes || {};
  const aiColors = tags.ai_colors || [];

  const categoryName = item.item_categories?.itc_name || 'Uncategorized';
  // The worker stores ai_colors as an object of hex values, so resolve the
  // primary colour to a display name rather than indexing it like an array.
  const colorName = getPrimaryColorName(aiColors);
  const fabric = aiAttributes.fabric || '';
  const occasion = aiAttributes.occasion || '';
  
  let displayTitle = '';
  if (colorName && fabric) {
    displayTitle = `${colorName} ${fabric} ${categoryName}`.trim();
  } else if (colorName) {
    displayTitle = `${colorName} ${categoryName}`.trim();
  } else {
    displayTitle = categoryName;
  }

  let displaySubtitle = '';
  if (fabric && occasion) {
    displaySubtitle = `${fabric} • ${occasion}`;
  } else if (fabric || occasion) {
    displaySubtitle = fabric || occasion;
  } else {
    displaySubtitle = 'Unknown Details';
  }

  const images = item.closet_item_images?.map(img => img.cii_url) || [];
  const thumbnailUrl = images.length > 0 ? images[0] : null;

  return {
    id: item.ci_id,
    categoryId: item.ci_category_id,
    categoryName: categoryName,
    status: item.ci_status,
    badgeStatus: badgeStatus, // Legacy, kept for compatibility
    status_label: badgeStatus,
    display_title: displayTitle,
    display_subtitle: displaySubtitle,
    thumbnail_url: thumbnailUrl,
    isFavorite: item.ci_is_favorite || false,
    isDeleted: item.ci_is_deleted,
    deletedAt: item.ci_deleted_at,
    images: images,
    attributes: item.closet_item_attributes || null,
  };
};

// --- Controllers ---

export const uploadItem = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    if (!userId) {
      return res.status(403).json({ success: false, message: 'User not synced in database.' });
    }

    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No image file provided' });
    }

    // Construct the local URL for the image
    const imageUrl = `/uploads/${req.file.filename}`;

    // Fetch the first category to use as a placeholder
    let firstCategory = await prisma.item_categories.findFirst();
    if (!firstCategory) {
      firstCategory = await prisma.item_categories.create({
        data: { itc_name: 'Uncategorized' }
      });
    }
    const categoryId = firstCategory.itc_id;

    const item = await prisma.closet_items.create({
      data: {
        ci_usr_id: userId,
        ci_category_id: categoryId,
        ci_status: 'AI_PROCESSING',
        closet_item_images: {
          create: {
            cii_url: imageUrl
          }
        }
      },
      include: {
        item_categories: true,
        closet_item_images: true,
      }
    });

    // Create the upload job for Python worker
    const job = await prisma.item_upload_jobs.create({
      data: {
        iuj_ci_id: item.ci_id,
        iuj_image_url: imageUrl,
        iuj_status: 'PENDING'
      }
    });

    res.status(201).json({
      success: true,
      data: {
        item: mapItemToDto(item),
        job: {
          id: job.iuj_id,
          status: job.iuj_status,
          imageUrl: job.iuj_image_url
        }
      }
    });
  } catch (error) {
    console.error('Error uploading item:', error);
    res.status(500).json({ success: false, message: 'Failed to upload item' });
  }
};

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
          closet_item_ai_tags: true,
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

export const getItemMetadata = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const itemId = parseInt(req.params.id);
    if (!userId) return res.status(403).json({ success: false, message: 'Forbidden' });

    const item = await prisma.closet_items.findUnique({
      where: { ci_id: itemId },
      include: {
        closet_item_images: true,
        closet_item_ai_tags: true,
        item_ai_responses: {
          orderBy: { iair_created_at: 'desc' },
          take: 1
        }
      }
    });

    if (!item || item.ci_usr_id !== userId || item.ci_is_deleted) {
      return res.status(404).json({ success: false, message: 'Item not found' });
    }

    const aiTags = item.closet_item_ai_tags?.ciaitag_tags || {};
    const aiAttributes = aiTags.ai_attributes || null;
    const aiColors = aiTags.ai_colors || null;

    // Format the unified response
    const metadata = {
      isFavorite: item.ci_is_favorite || false,
      image: item.closet_item_images?.[0]?.cii_url,
      attributes: mapAiAttributesToFlutter(aiAttributes),
      tags: [], // Using empty tags array for now, since Flutter relies on attributes
      colors: mapAiColorsToFlutter(aiColors),
      aiHistory: mapAiHistory(item.item_ai_responses),
      raw: {
        ai_attributes: aiAttributes,
        ai_colors: aiColors
      }
    };

    res.status(200).json({
      success: true,
      data: metadata,
    });
  } catch (error) {
    console.error('Error fetching item metadata:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch item metadata' });
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

    const { categoryId, status, manualAttributes, manualColors, isFavorite } = req.body;

    const item = await prisma.closet_items.update({
      where: { ci_id: itemId },
      data: {
        ...(categoryId && { ci_category_id: categoryId }),
        ...(status && { ci_status: status }),
        ...(isFavorite !== undefined && { ci_is_favorite: isFavorite }),
      },
      include: {
        item_categories: true,
      }
    });

    if (manualAttributes || manualColors) {
      const existingTags = await prisma.closet_item_ai_tags.findUnique({
        where: { ciaitag_ci_id: itemId }
      });
      
      let currentTags = existingTags?.ciaitag_tags || {};
      
      if (manualAttributes) {
        currentTags.ai_attributes = { ...currentTags.ai_attributes, ...manualAttributes };
        currentTags.is_edited = true;
      }
      if (manualColors) {
        currentTags.ai_colors = { ...currentTags.ai_colors, ...manualColors };
        currentTags.is_edited = true;
      }
      
      await prisma.closet_item_ai_tags.upsert({
         where: { ciaitag_ci_id: itemId },
         update: { ciaitag_tags: currentTags },
         create: { ciaitag_ci_id: itemId, ciaitag_tags: currentTags }
      });
    }

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

    // Cancel pending upload jobs
    await prisma.item_upload_jobs.updateMany({
      where: {
        iuj_ci_id: itemId,
        iuj_status: { in: ['PENDING', 'PROCESSING', 'ANALYZING'] }
      },
      data: {
        iuj_status: 'CANCELLED'
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

export const replaceItemImage = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const itemId = parseInt(req.params.id);
    
    if (!userId) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No image file provided' });
    }

    // Check ownership
    const existing = await prisma.closet_items.findUnique({
      where: { ci_id: itemId }
    });

    if (!existing || existing.ci_usr_id !== userId || existing.ci_is_deleted) {
      return res.status(404).json({ success: false, message: 'Item not found' });
    }

    const imageUrl = `/uploads/${req.file.filename}`;

    // Update image and status
    const item = await prisma.closet_items.update({
      where: { ci_id: itemId },
      data: {
        ci_status: 'AI_PROCESSING',
        closet_item_images: {
          deleteMany: {}, // Delete old images
          create: {
            cii_url: imageUrl
          }
        }
      },
      include: {
        item_categories: true,
        closet_item_images: true,
      }
    });

    // Create new upload job
    const job = await prisma.item_upload_jobs.create({
      data: {
        iuj_ci_id: itemId,
        iuj_image_url: imageUrl,
        iuj_status: 'PENDING'
      }
    });

    res.status(200).json({
      success: true,
      data: {
        item: mapItemToDto(item),
        job: {
          id: job.iuj_id,
          status: job.iuj_status,
          imageUrl: job.iuj_image_url
        }
      }
    });
  } catch (error) {
    console.error('Error replacing item image:', error);
    res.status(500).json({ success: false, message: 'Failed to replace image' });
  }
};
