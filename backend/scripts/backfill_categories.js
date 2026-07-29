/**
 * backfill_categories.js
 *
 * Re-derives ci_category_id for existing items from their stored raw AI
 * response, without calling the vision API again.
 *
 * Every item is created against a placeholder category and only gets its
 * real category once the worker's apply_ai_category() successfully matches
 * the AI's category/subcategory against item_categories. Two things left
 * items stuck on the placeholder:
 *   - the worker process wasn't running continuously, so apply_ai_category
 *     never ran for some items at all, and
 *   - even where it did run, some AI subcategories (e.g. "Choker") had no
 *     synonym entry yet, so the match failed and the item silently kept
 *     its placeholder category.
 *
 * This mirrors python-worker/database.py's CATEGORY_SYNONYMS and matching
 * rules (subcategory checked before category, synonym lookup, then simple
 * plural/singular variants) so results are consistent with what a live
 * worker run would now produce.
 *
 * Usage:
 *   node scripts/backfill_categories.js            # dry run, writes nothing
 *   node scripts/backfill_categories.js --confirm  # apply
 */
import 'dotenv/config';
import prisma from '../src/config/database.js';

const confirm = process.argv.includes('--confirm');

// Kept in sync with python-worker/database.py's CATEGORY_SYNONYMS.
const CATEGORY_SYNONYMS = {
  bottom: 'Pants', bottoms: 'Pants', jeans: 'Pants', denim: 'Pants',
  trousers: 'Pants', leggings: 'Pants', shorts: 'Pants',
  blouse: 'Top', tee: 'Top', 't-shirt': 'Top', tshirt: 'Top',
  sweater: 'Top', jumper: 'Top', cardigan: 'Top',
  gown: 'Dress', frock: 'Dress',
  pendant: 'Necklace', chain: 'Necklace', choker: 'Necklace', locket: 'Necklace',
  studs: 'Earrings', 'stud earrings': 'Earrings', hoops: 'Earrings',
  'hoop earrings': 'Earrings', 'drop earrings': 'Earrings',
  bangle: 'Bracelet', anklet: 'Bracelet', cuff: 'Bracelet',
  wristwatch: 'Watch',
  brooch: 'Accessory', belt: 'Accessory', scarf: 'Accessory', hat: 'Accessory',
  cap: 'Accessory', sunglasses: 'Accessory', gloves: 'Accessory',
  handbag: 'Bag', purse: 'Bag', tote: 'Bag', clutch: 'Bag', backpack: 'Bag',
  coat: 'Outerwear', jacket: 'Outerwear', blazer: 'Outerwear',
  'cardigan sweater': 'Outerwear',
  sneakers: 'Shoes', boots: 'Shoes', heels: 'Shoes', sandals: 'Shoes', flats: 'Shoes',
};

const resolveCategoryId = (categoryByLowerName, ...names) => {
  for (const name of names) {
    if (!name || !String(name).trim()) continue;
    const base = String(name).trim();

    const variants = [base];
    const synonym = CATEGORY_SYNONYMS[base.toLowerCase()];
    if (synonym) variants.push(synonym);

    const lowered = base.toLowerCase();
    if (lowered.endsWith('ies')) variants.push(base.slice(0, -3) + 'y');
    else if (lowered.endsWith('s')) variants.push(base.slice(0, -1));
    else {
      variants.push(base + 's');
      variants.push(base + 'es');
    }

    for (const variant of variants) {
      const id = categoryByLowerName.get(variant.toLowerCase());
      if (id) return id;
    }
  }
  return null;
};

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
  const categories = await prisma.item_categories.findMany();
  const categoryByLowerName = new Map(categories.map((c) => [c.itc_name.toLowerCase(), c.itc_id]));
  const categoryNameById = new Map(categories.map((c) => [c.itc_id, c.itc_name]));

  const items = await prisma.closet_items.findMany({
    where: { ci_is_deleted: false },
    include: { item_ai_responses: { orderBy: { iair_created_at: 'desc' }, take: 1 } },
    orderBy: { ci_id: 'asc' },
  });

  let changed = 0;
  let unchanged = 0;
  let noData = 0;

  for (const item of items) {
    const raw = parseRaw(item.item_ai_responses[0]?.iair_raw_response);
    if (!raw) {
      noData += 1;
      continue;
    }

    const matchedId = resolveCategoryId(categoryByLowerName, raw.subcategory, raw.category);
    if (!matchedId) {
      console.log(
        `  id=${item.ci_id} SKIP - no match for category=${raw.category} subcategory=${raw.subcategory}`
      );
      unchanged += 1;
      continue;
    }

    if (matchedId === item.ci_category_id) {
      unchanged += 1;
      continue;
    }

    console.log(
      `  id=${item.ci_id} ${categoryNameById.get(item.ci_category_id)} -> ${categoryNameById.get(matchedId)} ` +
        `(from category=${raw.category}, subcategory=${raw.subcategory})`
    );

    if (confirm) {
      await prisma.closet_items.update({
        where: { ci_id: item.ci_id },
        data: { ci_category_id: matchedId },
      });
    }
    changed += 1;
  }

  console.log(
    `\n${confirm ? 'Updated' : 'Would update'} ${changed}, unchanged ${unchanged}, no AI data ${noData}.`
  );
  if (!confirm && changed > 0) {
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
