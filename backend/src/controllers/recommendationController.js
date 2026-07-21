import prisma from '../config/database.js';

class CandidateSelector {
  static async getCandidates(userId, targetItem) {
    // Basic rule: if item is Jewelry, find Clothing. If Clothing, find Jewelry.
    // We'll just fetch all other active items for now as a simple Candidate Selector.
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
      take: 20 // Limit candidates for MVP
    });
  }
}

class ScoringEngine {
  static score(targetItem, candidateItem) {
    // A simple mock scoring engine based on rules. 
    // e.g. Gold matches Green.
    let score = 60 + Math.floor(Math.random() * 20); // Baseline 60-80
    
    // In a real implementation we would compare tags and colors.
    // For MVP, we'll randomize a bit just to show varying scores.
    return score;
  }
}

class RecommendationService {
  static async generate(userId, itemId) {
    // 1. Fetch Target Item
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

    // 2. Candidate Selector
    const candidates = await CandidateSelector.getCandidates(userId, targetItem);

    // 3. Scoring Engine
    const scored = candidates.map(c => ({
      item: c,
      score: ScoringEngine.score(targetItem, c)
    }));

    // 4. Sort and LLM Ranking (simulated)
    // Here we'd normally pass the top 5 to an LLM for final reasoning. 
    // We'll mock the reasoning for MVP.
    scored.sort((a, b) => b.score - a.score);
    const topMatches = scored.slice(0, 5);

    const recommendations = topMatches.map(match => {
      // Mock reasoning
      let reason = 'Style match based on recent trends.';
      if (match.score > 75) {
        reason = 'Colors complement each other perfectly.';
      }
      
      return {
        itemId: match.item.ci_id,
        score: match.score,
        reason: reason,
        itemData: {
          id: match.item.ci_id,
          categoryName: match.item.item_categories?.itc_name,
          images: match.item.closet_item_images.map(img => img.cii_url),
        }
      };
    });

    return {
      item: {
        id: targetItem.ci_id,
        categoryName: targetItem.item_categories?.itc_name,
        images: targetItem.closet_item_images.map(img => img.cii_url),
      },
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
