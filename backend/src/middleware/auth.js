import admin from '../config/firebase.js';
import { getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import prisma from '../config/database.js';

export const verifyFirebaseToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ status: 'ERROR', message: 'Unauthorized: No token provided' });
    }

    const token = authHeader.split('Bearer ')[1];
    
    let decodedToken;
    let dbUser;
    
    if (getApps().length === 0) {
      // Mock auth for local dev without service-account.json
      console.warn('⚠️ Firebase Admin not initialized. Using mock auth for local dev.');
      decodedToken = {
        uid: 'mock-user-123',
        email: 'mock@example.com'
      };
      
      // Auto-create or find mock user
      dbUser = await prisma.users.upsert({
        where: { usr_firebase_uid: decodedToken.uid },
        update: {},
        create: {
          usr_firebase_uid: decodedToken.uid,
          usr_email: decodedToken.email,
          usr_display_name: 'Dev User',
        }
      });
    } else {
      decodedToken = await getAuth().verifyIdToken(token);
      dbUser = await prisma.users.findUnique({
        where: { usr_firebase_uid: decodedToken.uid }
      });
    }
    
    req.user = decodedToken;
    
    if (dbUser) {
      req.dbUser = dbUser;
    }
    
    next();
  } catch (error) {
    console.error('Firebase token verification error:', error);
    return res.status(401).json({ status: 'ERROR', message: 'Unauthorized: Invalid token' });
  }
};
