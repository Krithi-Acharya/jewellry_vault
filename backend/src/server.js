import app from './app.js';
import config from './config/index.js';
import prisma from './config/database.js';

const start = async () => {
  try {
    // Verify database connection on startup
    await prisma.$connect();
    console.log('✅ Database connected');

    app.listen(config.port, () => {
      console.log(`✅ Server running on http://localhost:${config.port}`);
      console.log(`   Environment: ${config.nodeEnv}`);
      console.log(`   Health check: http://localhost:${config.port}/api/v1/health`);
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error.message);
    process.exit(1);
  }
};

// Graceful shutdown
const shutdown = async () => {
  console.log('\n🛑 Shutting down...');
  await prisma.$disconnect();
  process.exit(0);
};

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

start();
