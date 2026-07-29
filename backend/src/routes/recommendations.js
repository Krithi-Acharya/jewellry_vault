import { Router } from 'express';
import { verifyFirebaseToken } from '../middleware/auth.js';
import { getRecommendations, getPromptRecommendations, getOutfitRecommendations } from '../controllers/recommendationController.js';

const router = Router();

router.use(verifyFirebaseToken);

router.post('/prompt', getPromptRecommendations);
router.post('/outfits', getOutfitRecommendations);
router.get('/:itemId', getRecommendations);

export default router;


