import { Router } from 'express';
import { verifyFirebaseToken, requireAdmin } from '../middleware/auth.js';
import {
  getStats,
  getUsers,
  updateUserRole,
  getAllItems,
  adminDeleteItem,
  retryItem,
  getActivity,
  getQueue,
} from '../controllers/adminController.js';

const router = Router();

// Every route here requires a signed-in admin.
router.use(verifyFirebaseToken, requireAdmin);

router.get('/stats', getStats);
router.get('/activity', getActivity);
router.get('/queue', getQueue);
router.get('/users', getUsers);
router.patch('/users/:id/role', updateUserRole);
router.get('/items', getAllItems);
router.delete('/items/:id', adminDeleteItem);
router.post('/items/:id/retry', retryItem);

export default router;
