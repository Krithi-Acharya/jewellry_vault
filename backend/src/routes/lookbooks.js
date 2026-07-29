import { Router } from 'express';
import { verifyFirebaseToken } from '../middleware/auth.js';
import { createLookbookFromOutfit, getLookbooks } from '../controllers/lookbookController.js';

const router = Router();

router.use(verifyFirebaseToken);

router.get('/', getLookbooks);
router.post('/from-outfit', createLookbookFromOutfit);

export default router;
