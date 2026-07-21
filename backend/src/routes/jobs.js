import { Router } from 'express';
import { verifyFirebaseToken } from '../middleware/auth.js';
import { getJobById } from '../controllers/jobController.js';

const router = Router();

// All jobs routes require authentication
router.use(verifyFirebaseToken);

router.get('/:id', getJobById);

export default router;
