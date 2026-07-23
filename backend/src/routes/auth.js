import { Router } from 'express';
import { verifyFirebaseToken } from '../middleware/auth.js';
import { syncUser, getMe } from '../controllers/authController.js';

const router = Router();

// Endpoint to sync Firebase user to PostgreSQL
router.post('/sync-user', verifyFirebaseToken, syncUser);

// Returns the caller's own profile (used to check admin status on app load)
router.get('/me', verifyFirebaseToken, getMe);

export default router;
