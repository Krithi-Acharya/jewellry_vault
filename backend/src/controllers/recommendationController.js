import prisma from '../config/database.js';
import { mapItemToDto } from './itemController.js';
import { scorePromptMatch } from '../utils/promptScoring.js';
import { mapAiColorsToFlutter } from '../utils/aiMetadataMapper.js';

const OUTFIT_BASE_CATEGORIES = [
  'dress', 'shirt', 'top', 'skirt', 'pants', 'outerwear', 'gown', 'lehenga', 'saree', 'suit', 'jumpsuit', 'jeans', 'blazer', 't-shirt'
];

const JEWELRY_CATEGORIES = [
  'ring', 'necklace', 'earrings', 'bracelet', 'watch', 'pendant', 'bangle', 'anklet', 'jewelry', 'jewelry set'
];

function getColorWarmth(hex) {
  if (!hex) return null;
  const c = hex.replace('#', '');
  if (c.length !== 6) return null;
  const r = parseInt(c.slice(0, 2), 16) / 255;
  const g = parseInt(c.slice(2, 4), 16) / 255;
  const b = parseInt(c.slice(4, 6), 16) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  if (max - min < 0.08) return 'neutral';
  let hue = max === r ? ((g - b) / (max - min)) % 6 : max === g ? (b - r) / (max - min) + 2 : (r - g) / (max - min) + 4;
  hue = (hue * 60 + 360) % 360;
  if (hue < 70 || hue >= 320) return 'warm';
  if (hue >= 160 && hue < 260) return 'cool';
  return 'neutral';
}

function getMetalWarmth(metalType) {
  if (!metalType) return null;
  const m = metalType.toLowerCase();
  if (m.includes('gold') || m.includes('brass')) return 'warm';
  if (m.includes('silver') || m.includes('platinum') || m.includes('white gold') || m.includes('titanium') || m.includes('steel')) return 'cool';
  return null;
}

class CandidateSelector {
  static async getCandidates(userId, targetItem) {
    return await prisma.closet_items.findMany({
      where: {
        ci_usr_id: userId,
        ci_status: 'ACTIVE',
        ci_is_deleted: false,
        NOT: { ci_id: targetItem.ci_id }
      },
      include: {
        item_categories: true,
        closet_item_images: true,
        closet_item_ai_tags: true,
        closet_item_attributes: true
      },
      take: 20
    });
  }
}

class ScoringEngine {
  static score(targetItem, candidateItem, promptLower = '') {
    let score = 50;

    const targetAttrs = targetItem.closet_item_ai_tags?.ciaitag_tags?.ai_attributes || {};
    const candAttrs = candidateItem.closet_item_ai_tags?.ciaitag_tags?.ai_attributes || {};
    const targetCategory = (targetItem.item_categories?.itc_name || '').toLowerCase();
    const candCategory = (candidateItem.item_categories?.itc_name || '').toLowerCase();

    const isWorkPrompt = /job|work|office|meeting|interview|business|corporate|professional/i.test(promptLower);
    const isWorkGarment = ['work', 'office', 'formal', 'business'].includes((targetAttrs.occasion || '').toLowerCase()) ||
                          ['blazer', 'shirt', 'suit', 'pants', 'trousers'].includes(targetCategory);

    const isWeddingGarment = ['saree', 'lehenga'].includes(targetCategory) ||
                            ['wedding', 'festive', 'ethnic'].includes((targetAttrs.occasion || '').toLowerCase());

    if (isWorkPrompt || isWorkGarment) {
      // Work/Meeting favors subtle/minimalist jewelry
      if (['earrings', 'watch', 'pendant', 'bracelet', 'ring'].includes(candCategory)) {
        score += 25;
      }
      if (['jewelry set', 'choker'].includes(candCategory) || (candAttrs.style || '').toLowerCase().includes('bridal')) {
        score -= 35; // Heavy bridal jewelry sets are inappropriate for work/job meetings
      }
    } else if (isWeddingGarment) {
      // Traditional wear favors statement pieces
      if (['jewelry set', 'necklace'].includes(candCategory)) {
        score += 20;
      }
    }

    // Occasion match (Evening garment + Evening jewelry, etc.)
    if (targetAttrs.occasion && candAttrs.occasion &&
        targetAttrs.occasion.toLowerCase() === candAttrs.occasion.toLowerCase()) {
      score += 20;
    }

    // Style match (Ethnic + Ethnic, Formal + Formal)
    if (targetAttrs.style && candAttrs.style &&
        targetAttrs.style.toLowerCase() === candAttrs.style.toLowerCase()) {
      score += 15;
    }

    // Color-temperature harmony: garment's primary hue vs jewelry's metal
    const targetColors = mapAiColorsToFlutter(targetItem.closet_item_ai_tags?.ciaitag_tags?.ai_colors);
    const garmentWarmth = getColorWarmth(targetColors[0]?.hex);
    const jewelryWarmth = getMetalWarmth(candAttrs.metal_type);
    if (garmentWarmth && jewelryWarmth &&
        (garmentWarmth === 'neutral' || jewelryWarmth === 'neutral' || garmentWarmth === jewelryWarmth)) {
      score += 15;
    }

    return score;
  }
}


class RecommendationService {
  static async generate(userId, itemId) {
    const targetItem = await prisma.closet_items.findUnique({
      where: { ci_id: itemId },
      include: {
        item_categories: true,
        closet_item_ai_tags: true,
        closet_item_attributes: true,
        closet_item_images: true
      }
    });

    if (!targetItem || targetItem.ci_usr_id !== userId) {
      throw new Error('Target item not found');
    }

    const candidates = await CandidateSelector.getCandidates(userId, targetItem);
    const scored = candidates.map(c => ({
      item: c,
      score: ScoringEngine.score(targetItem, c)
    }));

    scored.sort((a, b) => b.score - a.score);
    const topMatches = scored.slice(0, 5);

    const recommendations = topMatches.map(match => {
      let reason = 'Style match based on recent trends.';
      if (match.score > 75) {
        reason = 'Colors complement each other perfectly.';
      }
      
      return {
        itemId: match.item.ci_id,
        score: match.score,
        reason: reason,
        itemData: mapItemToDto(match.item)
      };
    });

    return {
      item: mapItemToDto(targetItem),
      recommendations
    };
  }
}

export const getRecommendations = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const itemId = parseInt(req.params.itemId);
    
    if (!userId) return res.status(403).json({ success: false, message: 'Forbidden' });

    const result = await RecommendationService.generate(userId, itemId);

    res.status(200).json({
      success: true,
      data: result
    });
  } catch (error) {
    console.error('Error in getRecommendations:', error);
    res.status(500).json({ success: false, message: error.message || 'Failed to get recommendations' });
  }
};

export const getPromptRecommendations = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const { prompt } = req.body;

    if (!userId) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    if (!prompt || typeof prompt !== 'string' || !prompt.trim()) {
      return res.status(400).json({ success: false, message: 'Prompt text is required' });
    }

    const cleanPrompt = prompt.trim();
    const promptLower = cleanPrompt.toLowerCase();

    const userItems = await prisma.closet_items.findMany({
      where: {
        ci_usr_id: userId,
        ci_status: 'ACTIVE',
        ci_is_deleted: false,
      },
      include: {
        item_categories: true,
        closet_item_images: true,
        closet_item_ai_tags: true,
        closet_item_attributes: {
          include: {
            fabric_types: true,
            metal_types: true,
            gemstone_types: true,
            neckline_types: true,
          }
        }
      }
    });

    if (userItems.length === 0) {
      return res.status(200).json({
        success: true,
        data: {
          prompt: cleanPrompt,
          suggestionText: `For "${cleanPrompt}", start by uploading your favorite outfits and jewelry to your vault! Once added, JewelVault will automatically pick perfect combinations for every occasion.`,
          recommendedItems: [],
        }
      });
    }

    const scoredItems = userItems.map(item => ({
      item,
      score: scorePromptMatch(item, promptLower)
    }));

    let matchingItems = scoredItems.filter(entry => entry.score > 50);
    matchingItems.sort((a, b) => b.score - a.score);

    if (matchingItems.length === 0 && userItems.length > 0) {
      matchingItems = userItems.map(item => ({ item, score: 50 }));
    }

    const topMatches = matchingItems.slice(0, 4);
    const topRecommendedDtos = topMatches.map(match => mapItemToDto(match.item));

    let suggestionText = '';
    if (topRecommendedDtos.length === 0) {
      suggestionText = `We couldn't find a match in your closet for "${cleanPrompt}". Try uploading pieces that fit the occasion!`;
    } else {
      const mainItem = topRecommendedDtos[0];
      suggestionText = `Based on your request "${cleanPrompt}", I recommend wearing your ${mainItem.display_title}`;
      if (topRecommendedDtos.length > 1) {
        suggestionText += ` paired with your ${topRecommendedDtos[1].display_title} for a complete, stylish look.`;
      } else {
        suggestionText += ` — a stylish match from your vault!`;
      }
    }

    res.status(200).json({
      success: true,
      data: {
        prompt: cleanPrompt,
        suggestionText,
        recommendedItems: topRecommendedDtos,
      }
    });
  } catch (error) {
    console.error('Error in getPromptRecommendations:', error);
    res.status(500).json({ success: false, message: error.message || 'Failed to generate prompt recommendation' });
  }
};

export const getOutfitRecommendations = async (req, res) => {
  try {
    const userId = req.dbUser?.usr_id;
    const { prompt } = req.body;

    if (!userId) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }

    if (!prompt || typeof prompt !== 'string' || !prompt.trim()) {
      return res.status(400).json({ success: false, message: 'Prompt text is required' });
    }

    const cleanPrompt = prompt.trim();
    const promptLower = cleanPrompt.toLowerCase();

    const userItems = await prisma.closet_items.findMany({
      where: {
        ci_usr_id: userId,
        ci_status: 'ACTIVE',
        ci_is_deleted: false,
      },
      include: {
        item_categories: true,
        closet_item_images: true,
        closet_item_ai_tags: true,
        closet_item_attributes: {
          include: {
            fabric_types: true,
            metal_types: true,
            gemstone_types: true,
            neckline_types: true,
          }
        }
      }
    });

    if (userItems.length === 0) {
      return res.status(200).json({
        success: true,
        data: {
          prompt: cleanPrompt,
          suggestionText: `For "${cleanPrompt}", start by uploading your favorite outfits and jewelry to your vault! Once added, JewelVault will automatically pick perfect combinations for every occasion.`,
          outfits: []
        }
      });
    }

    const garmentItems = [];
    const jewelryItems = [];

    for (const item of userItems) {
      const catName = (item.item_categories?.itc_name || '').toLowerCase();
      if (JEWELRY_CATEGORIES.some(jCat => catName.includes(jCat))) {
        jewelryItems.push(item);
      } else {
        garmentItems.push(item);
      }
    }

    const scoredGarments = garmentItems.map(item => ({
      item,
      score: scorePromptMatch(item, promptLower)
    }));

    let matchingGarments = scoredGarments.filter(entry => entry.score >= 50);
    matchingGarments.sort((a, b) => b.score - a.score);

    const hasWellMatchedGarment = matchingGarments.some(entry => entry.score >= 65);

    // Fallback: If no garments scored >= 50 (e.g. all were penalized due to mismatch), sort all garments by score
    if (matchingGarments.length === 0 && garmentItems.length > 0) {
      matchingGarments = [...scoredGarments].sort((a, b) => b.score - a.score);
    }

    const topGarments = matchingGarments.slice(0, 5);

    if (topGarments.length === 0) {
      return res.status(200).json({
        success: true,
        data: {
          prompt: cleanPrompt,
          suggestionText: `We couldn't find any items in your closet for "${cleanPrompt}". Try uploading pieces to your vault!`,
          outfits: []
        }
      });
    }

    const outfits = topGarments.map(garmentEntry => {
      const garmentItem = garmentEntry.item;
      const garmentScore = garmentEntry.score;

      const scoredJewelry = jewelryItems.map(jItem => ({
        item: jItem,
        score: ScoringEngine.score(garmentItem, jItem, promptLower)
      }));

      scoredJewelry.sort((a, b) => b.score - a.score);
      const topJewelry = scoredJewelry.slice(0, 5);

      return {
        garment: mapItemToDto(garmentItem),
        matchScore: garmentScore,
        jewelryRecommendations: topJewelry.map(j => ({
          item: mapItemToDto(j.item),
          score: j.score
        }))
      };
    });

    let suggestionText = `Curated ${outfits.length} outfit candidate${outfits.length > 1 ? 's' : ''} for "${cleanPrompt}" with matching jewelry recommendations.`;

    if (!hasWellMatchedGarment && garmentItems.length > 0) {
      suggestionText = `Note: We didn't find specific workwear or formal items matching "${cleanPrompt}" in your vault. Below are available candidates from your closet, but consider adding formal shirts, blazers, or trousers for job meetings!`;
    }

    res.status(200).json({
      success: true,
      data: {
        prompt: cleanPrompt,
        suggestionText: `Curated ${outfits.length} outfit candidate${outfits.length > 1 ? 's' : ''} for "${cleanPrompt}" with matching jewelry recommendations.`,
        outfits
      }
    });
  } catch (error) {
    console.error('Error in getOutfitRecommendations:', error);
    res.status(500).json({ success: false, message: error.message || 'Failed to generate outfit recommendations' });
  }
};
