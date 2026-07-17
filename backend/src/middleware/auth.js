import admin from '../config/firebase.js';
import prisma from '../config/database.js';

export const verifyFirebaseToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ status: 'ERROR', message: 'Unauthorized: No token provided' });
    }

    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);
    
    // Attach Firebase user info to request
    req.user = decodedToken;
    
    // Fetch corresponding database user
    const dbUser = await prisma.users.findUnique({
      where: { usr_firebase_uid: decodedToken.uid }
    });
    
    if (dbUser) {
      req.dbUser = dbUser;
    }
    
    next();
  } catch (error) {
    console.error('Firebase token verification error:', error);
    return res.status(401).json({ status: 'ERROR', message: 'Unauthorized: Invalid token' });
  }
};
