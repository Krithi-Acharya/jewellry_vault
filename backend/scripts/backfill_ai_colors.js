/**
 * backfill_ai_colors.js
 *
 * Rebuilds closet_item_ai_tags from the raw vision-model responses already
 * stored in item_ai_responses.
 *
 * Older records were written by a pipeline that derived colours with K-means,
 * which frequently sampled the photo's background rather than the garment
 * (e.g. a pale yellow dress stored as #cccabf). The model's own response is the
 * better source and is already persisted, so this repairs the data without
 * spending any tokens.
 *
 * Usage:
 *   node scripts/backfill_ai_colors.js            # dry run, writes nothing
 *   node scripts/backfill_ai_colors.js --confirm  # apply
 */
import 'dotenv/config';
import prisma from '../src/config/database.js';

const confirm = process.argv.includes('--confirm');

/** The raw response is stored as JSON, but may arrive as a string. */
const parseRaw = (raw) => {
  if (!raw) return null;
  if (typeof raw === 'object') return raw;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
};

const main = async () => {
  const items = await prisma.closet_items.findMany({
    where: { ci_is_deleted: false },
    include: {
      closet_item_ai_tags: true,
      item_ai_responses: { orderBy: { iair_created_at: 'desc' }, take: 1 },
    },
    orderBy: { ci_id: 'asc' },
  });

  let updated = 0;
  let skipped = 0;

  for (const item of items) {
    const raw = parseRaw(item.item_ai_responses[0]?.iair_raw_response);

    if (!raw) {
      console.log(`  id=${item.ci_id} SKIP - no raw AI response stored`);
      skipped += 1;
      continue;
    }

    const { primary_color, secondary_color, ...attributes } = raw;

    const colors = [primary_color, secondary_color].filter(Boolean);

    if (colors.length === 0) {
      console.log(`  id=${item.ci_id} SKIP - response predates the colour field`);
      skipped += 1;
      continue;
    }

    const previous = item.closet_item_ai_tags?.ciaitag_tags?.ai_colors;
    const describe = (c) =>
      typeof c === 'string' ? c : `${c?.name ?? '?'} ${c?.hex ?? ''}`.trim();

    console.log(
      `  id=${item.ci_id} ${JSON.stringify(previous)} -> ` +
        `[${colors.map(describe).join(', ')}]`
    );

    if (confirm) {
      const tags = { ai_colors: colors, ai_attributes: attributes };
      await prisma.closet_item_ai_tags.upsert({
        where: { ciaitag_ci_id: item.ci_id },
        update: { ciaitag_tags: tags },
        create: { ciaitag_ci_id: item.ci_id, ciaitag_tags: tags },
      });
    }

    updated += 1;
  }

  console.log(`\n${confirm ? 'Updated' : 'Would update'} ${updated}, skipped ${skipped}.`);
  if (!confirm && updated > 0) {
    console.log('DRY RUN - re-run with --confirm to apply.');
  }
};

main()
  .catch((error) => {
    console.error('Backfill failed:', error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
