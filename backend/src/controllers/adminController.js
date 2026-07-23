import prisma from '../config/database.js';
import { mapItemToDto } from './itemController.js';

const ALLOWED_ROLES = ['user', 'admin'];

// --- Stats ---

export const getStats = async (req, res) => {
  try {
    const [
      totalUsers,
      totalItems,
      activeItems,
      processingItems,
      itemsMissingAiTags,
      itemsByCategory,
      recentSignups,
    ] = await Promise.all([
      prisma.users.count(),
      prisma.closet_items.count({ where: { ci_is_deleted: false } }),
      prisma.closet_items.count({ where: { ci_is_deleted: false, ci_status: 'ACTIVE' } }),
      prisma.closet_items.count({ where: { ci_is_deleted: false, ci_status: 'AI_PROCESSING' } }),
      prisma.closet_items.count({
        where: { ci_is_deleted: false, closet_item_ai_tags: { is: null } },
      }),
      prisma.closet_items.groupBy({
        by: ['ci_category_id'],
        where: { ci_is_deleted: false },
        _count: { ci_id: true },
      }),
      prisma.users.count({
        where: { usr_created_at: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } },
      }),
    ]);

    const categories = await prisma.item_categories.findMany();
    const categoryNameById = Object.fromEntries(categories.map((c) => [c.itc_id, c.itc_name]));

    res.status(200).json({
      success: true,
      data: {
        totalUsers,
        newUsersLast7Days: recentSignups,
        totalItems,
        activeItems,
        processingItems,
        itemsByCategory: itemsByCategory
          .map((row) => ({
            category: categoryNameById[row.ci_category_id] ?? 'Uncategorized',
            count: row._count.ci_id,
          }))
          .sort((a, b) => b.count - a.count),
        itemsMissingAiTags,
      },
    });
  } catch (error) {
    console.error('Error fetching admin stats:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch stats' });
  }
};

// --- Users ---

export const getUsers = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;

    const [users, total] = await Promise.all([
      prisma.users.findMany({
        skip,
        take: limit,
        orderBy: { usr_created_at: 'desc' },
        include: { _count: { select: { closet_items: true } } },
      }),
      prisma.users.count(),
    ]);

    res.status(200).json({
      success: true,
      data: users.map((u) => ({
        id: u.usr_id,
        email: u.usr_email,
        phoneNumber: u.usr_phone_number,
        displayName: u.usr_display_name || [u.usr_first_name, u.usr_last_name].filter(Boolean).join(' ') || null,
        role: u.usr_role,
        itemCount: u._count.closet_items,
        createdAt: u.usr_created_at,
      })),
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch users' });
  }
};

export const updateUserRole = async (req, res) => {
  try {
    const targetId = parseInt(req.params.id);
    const { role } = req.body;

    if (!ALLOWED_ROLES.includes(role)) {
      return res.status(400).json({
        success: false,
        message: `role must be one of: ${ALLOWED_ROLES.join(', ')}`,
      });
    }

    if (targetId === req.dbUser.usr_id && role !== 'admin') {
      return res.status(400).json({
        success: false,
        message: 'You cannot revoke your own admin access',
      });
    }

    const target = await prisma.users.findUnique({ where: { usr_id: targetId } });
    if (!target) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const updated = await prisma.users.update({
      where: { usr_id: targetId },
      data: { usr_role: role },
    });

    res.status(200).json({
      success: true,
      data: { id: updated.usr_id, email: updated.usr_email, role: updated.usr_role },
    });
  } catch (error) {
    console.error('Error updating user role:', error);
    res.status(500).json({ success: false, message: 'Failed to update role' });
  }
};

// --- Items (across all users) ---

export const getAllItems = async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const skip = (page - 1) * limit;

    const [items, total] = await Promise.all([
      prisma.closet_items.findMany({
        where: { ci_is_deleted: false },
        skip,
        take: limit,
        orderBy: { ci_id: 'desc' },
        include: {
          item_categories: true,
          closet_item_images: true,
          closet_item_ai_tags: true,
          users: { select: { usr_id: true, usr_email: true } },
        },
      }),
      prisma.closet_items.count({ where: { ci_is_deleted: false } }),
    ]);

    res.status(200).json({
      success: true,
      data: items.map((item) => ({
        ...mapItemToDto(item),
        ownerId: item.users.usr_id,
        ownerEmail: item.users.usr_email,
      })),
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    });
  } catch (error) {
    console.error('Error fetching all items:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch items' });
  }
};

/**
 * Moderation delete: removes any user's item, unlike the regular delete
 * endpoint which only allows removing your own. Uses the same soft-delete
 * convention as the owner-facing endpoint.
 */
export const adminDeleteItem = async (req, res) => {
  try {
    const itemId = parseInt(req.params.id);

    const existing = await prisma.closet_items.findUnique({ where: { ci_id: itemId } });
    if (!existing || existing.ci_is_deleted) {
      return res.status(404).json({ success: false, message: 'Item not found' });
    }

    await prisma.closet_items.update({
      where: { ci_id: itemId },
      data: { ci_is_deleted: true, ci_deleted_at: new Date() },
    });

    await prisma.item_upload_jobs.updateMany({
      where: {
        iuj_ci_id: itemId,
        iuj_status: { in: ['PENDING', 'PROCESSING', 'ANALYZING'] },
      },
      data: { iuj_status: 'FAILED', iuj_last_error: 'Removed by admin' },
    });

    res.status(200).json({ success: true, message: 'Item removed' });
  } catch (error) {
    console.error('Error removing item (admin):', error);
    res.status(500).json({ success: false, message: 'Failed to remove item' });
  }
};

// --- Retry stuck item ---

export const retryItem = async (req, res) => {
  try {
    const itemId = parseInt(req.params.id);

    const existing = await prisma.closet_items.findUnique({ where: { ci_id: itemId } });
    if (!existing || existing.ci_is_deleted) {
      return res.status(404).json({ success: false, message: 'Item not found' });
    }

    // Reset item status back to AI_PROCESSING
    await prisma.closet_items.update({
      where: { ci_id: itemId },
      data: { ci_status: 'AI_PROCESSING' },
    });

    // Cancel any FAILED jobs and re-queue by resetting them to PENDING
    await prisma.item_upload_jobs.updateMany({
      where: { iuj_ci_id: itemId, iuj_status: { in: ['FAILED', 'ANALYZING'] } },
      data: { iuj_status: 'PENDING', iuj_last_error: null, iuj_retry_count: 0 },
    });

    res.status(200).json({ success: true, message: 'Item queued for retry' });
  } catch (error) {
    console.error('Error retrying item (admin):', error);
    res.status(500).json({ success: false, message: 'Failed to retry item' });
  }
};

// --- Activity feed (derived from existing timestamps, no schema change) ---

export const getActivity = async (req, res) => {
  try {
    const limit = 20;

    // Recent item deletions
    const deletedItems = await prisma.closet_items.findMany({
      where: { ci_is_deleted: true, ci_deleted_at: { not: null } },
      orderBy: { ci_deleted_at: 'desc' },
      take: limit,
      include: { users: { select: { usr_email: true } } },
    });

    // Recent user sign-ups
    const newUsers = await prisma.users.findMany({
      orderBy: { usr_created_at: 'desc' },
      take: limit,
      select: { usr_id: true, usr_email: true, usr_display_name: true, usr_role: true, usr_created_at: true },
    });

    // Merge & sort by timestamp descending
    const events = [
      ...deletedItems.map((item) => ({
        type: 'item_deleted',
        description: `Item "${item.ci_display_title ?? 'Unknown'}" removed`,
        actor: item.users?.usr_email ?? 'unknown',
        timestamp: item.ci_deleted_at,
      })),
      ...newUsers.map((u) => ({
        type: 'user_joined',
        description: `${u.usr_display_name || u.usr_email} joined`,
        actor: u.usr_email,
        timestamp: u.usr_created_at,
      })),
    ]
      .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp))
      .slice(0, limit);

    res.status(200).json({ success: true, data: events });
  } catch (error) {
    console.error('Error fetching activity:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch activity' });
  }
};

// --- AI queue (items stuck in processing) ---

export const getQueue = async (req, res) => {
  try {
    const items = await prisma.closet_items.findMany({
      where: {
        ci_is_deleted: false,
        ci_status: { in: ['AI_PROCESSING', 'PENDING'] },
      },
      orderBy: { ci_created_at: 'asc' },
      take: 50,
      include: {
        users: { select: { usr_id: true, usr_email: true } },
        closet_item_images: { take: 1 },
        item_upload_jobs: {
          orderBy: { iuj_id: 'desc' },
          take: 1,
          select: { iuj_status: true, iuj_last_error: true, iuj_retry_count: true },
        },
      },
    });

    res.status(200).json({
      success: true,
      data: items.map((item) => ({
        id: item.ci_id,
        displayTitle: item.ci_display_title ?? 'Unnamed item',
        status: item.ci_status,
        ownerEmail: item.users?.usr_email,
        ownerId: item.users?.usr_id,
        createdAt: item.ci_created_at,
        thumbnailUrl: item.closet_item_images?.[0]?.cii_image_url ?? null,
        latestJob: item.item_upload_jobs?.[0] ?? null,
      })),
    });
  } catch (error) {
    console.error('Error fetching AI queue:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch queue' });
  }
};
