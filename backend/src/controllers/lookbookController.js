import prisma from '../config/database.js';
import { mapItemToDto } from './itemController.js';

export const createLookbookFromOutfit = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const { garmentItemId, jewelryItemIds, name } = req.body;

    if (!userId) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    if (!garmentItemId) {
      return res.status(400).json({ success: false, message: 'garmentItemId is required' });
    }

    const itemIds = [garmentItemId, ...(Array.isArray(jewelryItemIds) ? jewelryItemIds : [])];

    // Verify item IDs belong to user and are active
    const userItems = await prisma.closet_items.findMany({
      where: {
        ci_usr_id: userId,
        ci_id: { in: itemIds },
        ci_is_deleted: false,
      },
      include: {
        item_categories: true,
        closet_item_images: true,
        closet_item_ai_tags: true,
        closet_item_attributes: true,
      }
    });

    if (userItems.length === 0) {
      return res.status(404).json({ success: false, message: 'No valid closet items found' });
    }

    const garmentItem = userItems.find(i => i.ci_id === garmentItemId);
    const garmentDto = garmentItem ? mapItemToDto(garmentItem) : null;
    const lookbookName = name || (garmentDto ? `${garmentDto.display_title} Look` : 'Saved Lookbook');

    const newLookbook = await prisma.lookbooks.create({
      data: {
        lb_usr_id: userId,
        lb_name: lookbookName,
        lookbook_items: {
          create: userItems.map(item => ({
            lbi_ci_id: item.ci_id,
          }))
        }
      },
      include: {
        lookbook_items: {
          include: {
            closet_items: {
              include: {
                item_categories: true,
                closet_item_images: true,
                closet_item_ai_tags: true,
                closet_item_attributes: true,
              }
            }
          }
        }
      }
    });

    const itemsDto = newLookbook.lookbook_items.map(lbi => mapItemToDto(lbi.closet_items));

    res.status(201).json({
      success: true,
      data: {
        id: newLookbook.lb_id,
        name: newLookbook.lb_name,
        items: itemsDto,
      }
    });
  } catch (error) {
    console.error('Error in createLookbookFromOutfit:', error);
    res.status(500).json({ success: false, message: error.message || 'Failed to create lookbook' });
  }
};

export const getLookbooks = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    if (!userId) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    const lookbooks = await prisma.lookbooks.findMany({
      where: {
        lb_usr_id: userId,
      },
      include: {
        lookbook_items: {
          include: {
            closet_items: {
              include: {
                item_categories: true,
                closet_item_images: true,
                closet_item_ai_tags: true,
                closet_item_attributes: true,
              }
            }
          }
        }
      },
      orderBy: {
        lb_id: 'desc',
      }
    });

    const mappedLookbooks = lookbooks.map(lb => ({
      id: lb.lb_id,
      name: lb.lb_name || 'Saved Lookbook',
      items: lb.lookbook_items.map(lbi => mapItemToDto(lbi.closet_items)),
    }));

    res.status(200).json({
      success: true,
      data: mappedLookbooks,
    });
  } catch (error) {
    console.error('Error in getLookbooks:', error);
    res.status(500).json({ success: false, message: error.message || 'Failed to fetch lookbooks' });
  }
};
