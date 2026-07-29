const OCCASION_SYNONYMS = {
  // Work & Professional
  work: ['work', 'office', 'formal', 'business', 'corporate', 'professional', 'interview', 'meeting', 'conference', 'presentation', 'shirt', 'blazer', 'suit', 'pants', 'trousers', 'formal dress'],
  job: ['work', 'office', 'formal', 'business', 'corporate', 'professional', 'interview', 'meeting', 'conference', 'presentation', 'shirt', 'blazer', 'suit', 'pants', 'trousers', 'formal dress'],
  office: ['work', 'office', 'formal', 'business', 'corporate', 'professional', 'interview', 'meeting', 'conference', 'presentation', 'shirt', 'blazer', 'suit', 'pants', 'trousers', 'formal dress'],
  meeting: ['work', 'office', 'formal', 'business', 'corporate', 'professional', 'interview', 'meeting', 'conference', 'presentation', 'shirt', 'blazer', 'suit', 'pants', 'trousers', 'formal dress'],
  interview: ['work', 'office', 'formal', 'business', 'corporate', 'professional', 'interview', 'meeting', 'conference', 'presentation', 'shirt', 'blazer', 'suit', 'pants', 'trousers', 'formal dress'],
  business: ['work', 'office', 'formal', 'business', 'corporate', 'professional', 'interview', 'meeting', 'conference', 'presentation', 'shirt', 'blazer', 'suit', 'pants', 'trousers', 'formal dress'],
  corporate: ['work', 'office', 'formal', 'business', 'corporate', 'professional', 'interview', 'meeting', 'conference', 'presentation', 'shirt', 'blazer', 'suit', 'pants', 'trousers', 'formal dress'],

  // Wedding, Festive & Ethnic
  wedding: ['wedding', 'festive', 'ethnic', 'traditional', 'lehenga', 'saree', 'gown', 'bridal', 'marriage', 'reception', 'sangeet', 'haldi', 'pooja'],
  festive: ['festive', 'wedding', 'ethnic', 'traditional', 'saree', 'lehenga', 'gown', 'silk', 'pooja', 'diwali'],
  traditional: ['ethnic', 'traditional', 'saree', 'lehenga', 'festive', 'wedding', 'pooja'],
  ethnic: ['ethnic', 'traditional', 'saree', 'lehenga', 'festive', 'wedding'],
  lehenga: ['ethnic', 'traditional', 'lehenga', 'festive', 'wedding'],
  saree: ['ethnic', 'traditional', 'saree', 'festive', 'wedding'],

  // Romantic & Dates
  date: ['evening', 'party', 'romantic', 'dinner', 'dress', 'gown'],
  romantic: ['evening', 'party', 'romantic', 'dinner', 'dress', 'gown'],

  // Party & Nightlife
  party: ['party', 'evening', 'cocktail', 'club', 'night', 'festive', 'dress', 'gown', 'silk'],
  dinner: ['evening', 'party', 'formal', 'cocktail', 'dress', 'gown'],
  night: ['evening', 'party', 'cocktail', 'club', 'dress', 'gown'],
  club: ['party', 'evening', 'cocktail', 'club', 'night', 'dress'],

  // Casual & Everyday
  casual: ['everyday', 'casual', 'top', 'pants', 'skirt', 'dress', 'cotton', 'denim', 't-shirt', 'jeans'],
  everyday: ['everyday', 'casual', 'top', 'pants', 'skirt', 'dress', 'cotton', 'denim', 't-shirt', 'jeans'],
  park: ['everyday', 'casual', 'cotton', 'top', 'pants', 'skirt', 'dress', 'denim', 'shorts', 't-shirt'],
  picnic: ['everyday', 'casual', 'cotton', 'top', 'pants', 'skirt', 'dress', 'denim', 'shorts', 't-shirt'],
  brunch: ['casual', 'everyday', 'dress', 'top', 'skirt', 'cotton', 'linen'],
  outdoor: ['everyday', 'casual', 'cotton', 'top', 'pants', 'skirt', 'dress', 'denim'],
  beach: ['casual', 'everyday', 'dress', 'skirt', 'cotton', 'linen', 'shorts'],
};

const OUTFIT_KEYWORDS = ['outfit', 'wear', 'dressing', 'look', 'style', 'clothes', 'clothing', 'something', 'create', 'suggest', 'find'];

const PROMPT_INTENT_PATTERNS = {
  work: /\b(job|work|office|meeting|interview|business|corporate|conference|presentation|professional)\b/i,
  wedding: /\b(wedding|marriage|reception|sangeet|haldi|mehendi|bridal|festive|pooja|diwali|ethnic|traditional|lehenga|saree)\b/i,
  party: /\b(party|nightclub|club|cocktail|gala|night out|celebration)\b/i,
  casual: /\b(casual|everyday|park|picnic|beach|vacation|loungewear|home)\b/i,
};

/**
 * Shared prompt scoring function for closet items.
 * Evaluates category, occasion, fabric, formality, synonyms, and intent relevance against a prompt string.
 */
export const scorePromptMatch = (item, promptLower) => {
  let score = 50;
  const catName = (item.item_categories?.itc_name || '').toLowerCase();
  const tags = item.closet_item_ai_tags?.ciaitag_tags || {};
  const aiAttrs = tags.ai_attributes || {};
  const itemOccasion = (aiAttrs.occasion || '').toLowerCase();
  const itemFabric = (aiAttrs.fabric || '').toLowerCase();
  const itemStyle = (aiAttrs.style || '').toLowerCase();

  // Detect prompt intent
  let promptIntent = null;
  if (PROMPT_INTENT_PATTERNS.work.test(promptLower)) {
    promptIntent = 'work';
  } else if (PROMPT_INTENT_PATTERNS.wedding.test(promptLower)) {
    promptIntent = 'wedding';
  } else if (PROMPT_INTENT_PATTERNS.party.test(promptLower)) {
    promptIntent = 'party';
  } else if (PROMPT_INTENT_PATTERNS.casual.test(promptLower)) {
    promptIntent = 'casual';
  }

  // Intent-based scoring & mismatch penalties
  if (promptIntent === 'work') {
    const isWorkItem = ['work', 'office', 'formal', 'business', 'professional'].includes(itemOccasion) ||
                       ['work', 'office', 'formal', 'business', 'professional'].includes(itemStyle) ||
                       ['shirt', 'blazer', 'suit', 'pants', 'trousers', 'formal dress'].includes(catName);
    if (isWorkItem) {
      score += 35;
    }

    const isHeavyWeddingOrParty = ['wedding', 'festive', 'bridal', 'party', 'ethnic'].includes(itemOccasion) ||
                                  ['lehenga', 'saree', 'gown'].includes(catName) ||
                                  ['ethnic', 'traditional', 'bridal'].includes(itemStyle);
    if (isHeavyWeddingOrParty) {
      score -= 40; // Heavy penalty for wearing bridal/wedding/festive wear to work/meetings
    }
  } else if (promptIntent === 'wedding') {
    const isWeddingItem = ['wedding', 'festive', 'ethnic', 'traditional', 'bridal'].includes(itemOccasion) ||
                          ['lehenga', 'saree', 'gown', 'anarkali'].includes(catName) ||
                          ['ethnic', 'traditional', 'bridal'].includes(itemStyle);
    if (isWeddingItem) {
      score += 35;
    }

    const isWorkOrCasual = ['work', 'office', 'casual', 'everyday'].includes(itemOccasion) ||
                           ['t-shirt', 'jeans', 'blazer', 'trackpants'].includes(catName);
    if (isWorkOrCasual) {
      score -= 40;
    }
  } else if (promptIntent === 'casual') {
    const isCasualItem = ['casual', 'everyday'].includes(itemOccasion) ||
                         ['t-shirt', 'jeans', 'top', 'shorts', 'skirt', 'denim', 'cotton'].includes(catName);
    if (isCasualItem) {
      score += 30;
    }

    const isHeavyItem = ['lehenga', 'heavy gown', 'bridal'].includes(catName) ||
                        ['wedding', 'festive', 'bridal'].includes(itemOccasion);
    if (isHeavyItem) {
      score -= 30;
    }
  }

  // Category direct match
  if (catName && promptLower.includes(catName)) score += 30;

  // Direct attribute matches
  if (itemOccasion && promptLower.includes(itemOccasion)) score += 25;
  if (itemFabric && promptLower.includes(itemFabric)) score += 15;
  if (itemStyle && promptLower.includes(itemStyle)) score += 15;

  // Occasion & intent synonym matching
  for (const [key, synonyms] of Object.entries(OCCASION_SYNONYMS)) {
    if (promptLower.includes(key)) {
      if (synonyms.includes(itemOccasion) || synonyms.includes(catName) || synonyms.includes(itemStyle) || synonyms.includes(itemFabric)) {
        score += 20;
      }
    }
  }

  // General outfit request intent boost
  if (OUTFIT_KEYWORDS.some(kw => promptLower.includes(kw))) {
    score += 10;
  }

  // Individual word matches
  const titleWords = `${catName} ${itemFabric} ${itemOccasion} ${itemStyle}`.split(' ');
  for (const word of titleWords) {
    if (word.length > 3 && promptLower.includes(word)) score += 5;
  }

  return score;
};

