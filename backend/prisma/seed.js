import { PrismaClient } from '@prisma/client';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';
import 'dotenv/config';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('Seeding item categories...');
  
  const categories = [
    'Dress',
    'Shirt',
    'Top',
    'Skirt',
    'Pants',
    'Ring',
    'Necklace',
    'Earrings',
    'Bracelet',
    'Watch'
  ];

  for (const category of categories) {
    await prisma.item_categories.upsert({
      where: { itc_name: category },
      update: {},
      create: { itc_name: category },
    });
  }

  console.log('Seeding complete.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
