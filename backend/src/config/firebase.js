import admin from 'firebase-admin';
import config from './index.js';

// Initialize Firebase Admin
// In production, use GOOGLE_APPLICATION_CREDENTIALS or pass the service account JSON
try {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
  console.log('✅ Firebase Admin initialized');
} catch (error) {
  console.error('❌ Firebase Admin initialization error:', error.message);
}

export default admin;
