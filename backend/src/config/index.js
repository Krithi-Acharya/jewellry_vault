import dotenv from 'dotenv';
dotenv.config();

// Fail loudly on missing required config. Without this the app gets a long way
// into startup before failing deep inside the pg driver with an unhelpful
// "client password must be a string".
if (!process.env.DATABASE_URL) {
  console.error(
    '❌ DATABASE_URL is not set.\n' +
    '   Copy backend/.env.example to backend/.env and fill in your connection string.'
  );
  process.exit(1);
}

const config = {
  port: process.env.PORT || 5000,
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL,
  cors: {
    origin: process.env.CORS_ORIGIN || '*',
  },
};

export default config;
