import { Router } from 'express';
import healthRoutes from './health.js';
import authRoutes from './auth.js';
import itemRoutes from './items.js';
import jobRoutes from './jobs.js';
import recommendationRoutes from './recommendations.js';
import lookbookRoutes from './lookbooks.js';
import adminRoutes from './admin.js';
import outfitRoutes from './outfits.js';

const router = Router();

router.use('/', healthRoutes);
router.use('/auth', authRoutes);
router.use('/items', itemRoutes);
router.use('/jobs', jobRoutes);
router.use('/recommendations', recommendationRoutes);
router.use('/lookbooks', lookbookRoutes);
router.use('/admin', adminRoutes);
router.use('/outfits', outfitRoutes);

export default router;

