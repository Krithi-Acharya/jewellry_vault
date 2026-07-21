import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import helmet from 'helmet';
import path from 'path';
import { fileURLToPath } from 'url';
import config from './config/index.js';
import routes from './routes/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// ─── Security ───────────────────────────────
app.use(helmet());

// ─── CORS ───────────────────────────────────
app.use(cors(config.cors));

// ─── Logging ────────────────────────────────
morgan.token('user', (req) => req.user ? req.user.uid : 'anonymous');
app.use(morgan(':method :url :status - :response-time ms - User: :user'));

// ─── Body Parsing ───────────────────────────
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve uploaded files statically.
// Allow cross-origin loading of images (Flutter Web fetches these from a different
// origin than the API); helmet's default same-origin CORP would otherwise block them.
app.use(
  '/uploads',
  (req, res, next) => {
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    next();
  },
  express.static(path.join(__dirname, '../public/uploads'))
);

// ─── API Routes ─────────────────────────────
app.use('/api/v1', routes);

// ─── 404 Handler ────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    status: 'NOT_FOUND',
    message: `Route ${req.method} ${req.originalUrl} not found`,
  });
});

// ─── Global Error Handler ───────────────────
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    status: 'ERROR',
    message: config.nodeEnv === 'development' ? err.message : 'Internal server error',
  });
});

export default app;
