import { Router } from 'express';
import { verifyFirebaseToken } from '../middleware/auth.js';
import { syncUser } from '../controllers/authController.js';

const router = Router();

// Endpoint to sync Firebase user to PostgreSQL
router.post('/sync-user', verifyFirebaseToken, syncUser);

export default router;
