import express from 'express';
import cors from 'cors';
import morgan from 'morgan';
import helmet from 'helmet';
import config from './config/index.js';
import routes from './routes/index.js';

const app = express();

// ─── Security ───────────────────────────────
app.use(helmet());

// ─── CORS ───────────────────────────────────
app.use(cors(config.cors));

// ─── Logging ────────────────────────────────
app.use(morgan('dev'));

// ─── Body Parsing ───────────────────────────
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

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
