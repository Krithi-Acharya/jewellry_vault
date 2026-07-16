import { Router } from 'express';
import healthRoutes from './health.js';
import authRoutes from './auth.js';
import itemRoutes from './items.js';

const router = Router();

router.use('/', healthRoutes);
router.use('/auth', authRoutes);
router.use('/items', itemRoutes);

export default router;
