// Import the tools we installed earlier
const express = require('express');
const { initializeApp, cert } = require('firebase-admin/app');

// Load the secret service account key
// This proves to Firebase that this server is trusted
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin using that key
initializeApp({
  credential: cert(serviceAccount),
});

// Create the actual web server
const app = express();

// This lets our server understand JSON data sent from Flutter
app.use(express.json());

// A simple test route — just to confirm the server works
app.get('/', (req, res) => {
  res.send('JewelVault backend is running!');
});

// Start listening for requests on port 5000
const PORT = 5000;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});