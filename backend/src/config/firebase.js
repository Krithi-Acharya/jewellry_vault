import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';

try {
  const serviceAccountPath = path.resolve(process.cwd(), 'service-account.json');
  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    admin.initializeApp({
      // firebase-admin v14 dropped the admin.credential.* namespace; cert()
      // is now exported directly on the default import.
      credential: admin.cert(serviceAccount),
    });
    console.log('✅ Firebase Admin initialized');
  } else {
    console.warn('⚠️ Firebase Admin NOT initialized: service-account.json not found in backend/ root');
  }
} catch (error) {
  console.error('❌ Firebase Admin initialization error:', error.message);
}

export default admin;
