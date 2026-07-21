import { Router } from 'express';
import { verifyFirebaseToken } from '../middleware/auth.js';
import { getRecommendations } from '../controllers/recommendationController.js';

const router = Router();

router.use(verifyFirebaseToken);

router.get('/:itemId', getRecommendations);

export default router;
