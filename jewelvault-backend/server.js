// Import the tools we installed earlier
const express = require('express');
const { initializeApp, cert } = require('firebase-admin/app');
const verifyToken = require('./authMiddleware');

// Load the secret service account key
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin using that key
initializeApp({
  credential: cert(serviceAccount),
});

// Create the actual web server
const app = express();
app.use(express.json());

// A simple test route
app.get('/', (req, res) => {
  res.send('JewelVault backend is running!');
});

// A protected route — only reachable with a valid token
app.get('/protected', verifyToken, (req, res) => {
  res.json({ message: 'You are authenticated!', user: req.user });
});

// Start listening for requests on port 5000
const PORT = 5000;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});