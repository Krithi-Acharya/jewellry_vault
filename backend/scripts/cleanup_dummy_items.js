/**
 * cleanup_dummy_items.js
 *
 * Removes demo/seed closet items that were never produced by a real upload.
 *
 * An item is considered "dummy" when either:
 *   - it has no image attached at all (seed rows), or
 *   - it is stranded in AI_PROCESSING (the worker never completed it).
 *
 * Items that are ACTIVE with an image are always preserved.
 *
 * Usage:
 *   node scripts/cleanup_dummy_items.js            # dry run, deletes nothing
 *   node scripts/cleanup_dummy_items.js --confirm  # actually delete
 *
 * Related rows (images, AI tags, attributes) are removed by the schema's
 * onDelete: Cascade rules.
 */
import 'dotenv/config';
import prisma from '../src/config/database.js';

const confirm = process.argv.includes('--confirm');

const main = async () => {
  const items = await prisma.closet_items.findMany({
    include: { closet_item_images: true, item_categories: true },
    orderBy: { ci_id: 'asc' },
  });

  const doomed = items.filter(
    (item) =>
      item.closet_item_images.length === 0 || item.ci_status === 'AI_PROCESSING'
  );

  const kept = items.filter((item) => !doomed.includes(item));

  console.log(`Scanned ${items.length} item(s).`);
  console.log(`\nWill KEEP ${kept.length}:`);
  for (const item of kept) {
    console.log(
      `  id=${item.ci_id} status=${item.ci_status} ` +
        `category=${item.item_categories?.itc_name ?? 'none'} ` +
        `images=${item.closet_item_images.length}`
    );
  }

  console.log(`\nWill DELETE ${doomed.length}:`);
  for (const item of doomed) {
    const why =
      item.closet_item_images.length === 0 ? 'no image' : 'stuck in AI_PROCESSING';
    console.log(
      `  id=${item.ci_id} status=${item.ci_status} ` +
        `category=${item.item_categories?.itc_name ?? 'none'} (${why})`
    );
  }

  if (doomed.length === 0) {
    console.log('\nNothing to clean up.');
    return;
  }

  if (!confirm) {
    console.log('\nDRY RUN - nothing was deleted.');
    console.log('Re-run with --confirm to apply.');
    return;
  }

  const result = await prisma.closet_items.deleteMany({
    where: { ci_id: { in: doomed.map((item) => item.ci_id) } },
  });

  console.log(`\nDeleted ${result.count} item(s).`);
};

main()
  .catch((error) => {
    console.error('Cleanup failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
