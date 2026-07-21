import { Router } from 'express';
import healthRoutes from './health.js';
import authRoutes from './auth.js';
import itemRoutes from './items.js';
import jobRoutes from './jobs.js';
import recommendationRoutes from './recommendations.js';

const router = Router();

router.use('/', healthRoutes);
router.use('/auth', authRoutes);
router.use('/items', itemRoutes);
router.use('/jobs', jobRoutes);
router.use('/recommendations', recommendationRoutes);

export default router;
