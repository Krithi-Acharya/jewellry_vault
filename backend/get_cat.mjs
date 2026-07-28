import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient();
async function main() {
  let cat = await prisma.item_categories.findFirst();
  if (!cat) {
    cat = await prisma.item_categories.create({ data: { itc_name: 'Uncategorized' } });
  }
  console.log(cat.itc_id);
}
main().finally(() => prisma.$disconnect());
