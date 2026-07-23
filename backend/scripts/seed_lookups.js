/**
 * seed_lookups.js
 *
 * Seeds the reference tables the app resolves AI output against.
 *
 * These are idempotent upserts keyed on the unique name column, so running it
 * repeatedly is safe and it can be used to bring a fresh database (or a new
 * environment) up to the same baseline.
 *
 * Usage:
 *   node scripts/seed_lookups.js
 */
import 'dotenv/config';
import prisma from '../src/config/database.js';

// Top-level categories the vision prompt is allowed to return. Without these
// an item the model classifies as e.g. "Outerwear" has nothing to link to and
// silently keeps its placeholder category.
const CATEGORIES = [
  'Dress', 'Shirt', 'Top', 'Skirt', 'Pants',
  'Outerwear', 'Shoes', 'Bag', 'Accessory',
  'Ring', 'Necklace', 'Earrings', 'Bracelet', 'Watch',
];

const FABRIC_TYPES = [
  'Cotton', 'Linen', 'Silk', 'Wool', 'Cashmere', 'Denim', 'Leather',
  'Polyester', 'Viscose', 'Satin', 'Velvet', 'Chiffon', 'Knit',
];

const METAL_TYPES = [
  'Gold', 'Yellow Gold', 'White Gold', 'Rose Gold',
  'Silver', 'Sterling Silver', 'Platinum', 'Titanium', 'Stainless Steel', 'Brass',
];

const GEMSTONE_TYPES = [
  'Diamond', 'Ruby', 'Sapphire', 'Emerald', 'Pearl', 'Opal', 'Amethyst',
  'Topaz', 'Garnet', 'Turquoise', 'Jade', 'Onyx', 'Cubic Zirconia',
];

const seed = async (label, names, upsert) => {
  let created = 0;
  for (const name of names) {
    const before = await upsert.count({ where: { name } });
    await upsert.run(name);
    if (before === 0) created += 1;
  }
  console.log(`${label}: ${names.length} total, ${created} newly created`);
};

const main = async () => {
  await seed('item_categories', CATEGORIES, {
    count: ({ where }) => prisma.item_categories.count({ where: { itc_name: where.name } }),
    run: (name) =>
      prisma.item_categories.upsert({
        where: { itc_name: name },
        update: {},
        create: { itc_name: name },
      }),
  });

  await seed('fabric_types', FABRIC_TYPES, {
    count: ({ where }) => prisma.fabric_types.count({ where: { fbt_name: where.name } }),
    run: (name) =>
      prisma.fabric_types.upsert({
        where: { fbt_name: name },
        update: {},
        create: { fbt_name: name },
      }),
  });

  await seed('metal_types', METAL_TYPES, {
    count: ({ where }) => prisma.metal_types.count({ where: { mtt_name: where.name } }),
    run: (name) =>
      prisma.metal_types.upsert({
        where: { mtt_name: name },
        update: {},
        create: { mtt_name: name },
      }),
  });

  await seed('gemstone_types', GEMSTONE_TYPES, {
    count: ({ where }) => prisma.gemstone_types.count({ where: { gst_name: where.name } }),
    run: (name) =>
      prisma.gemstone_types.upsert({
        where: { gst_name: name },
        update: {},
        create: { gst_name: name },
      }),
  });
};

main()
  .catch((error) => {
    console.error('Seeding failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
