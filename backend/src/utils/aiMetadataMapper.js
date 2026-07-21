/**
 * Maps the raw AI attributes JSON object to the array format expected by the Flutter UI.
 * 
 * Expected JSON from Python worker:
 * {
 *   "style": "Bohemian",
 *   "fabric": "Cotton",
 *   "confidence": 0.9,
 *   "final_confidence": 0.9,
 *   ...
 * }
 */
export const mapAiAttributesToFlutter = (aiAttributes) => {
  if (!aiAttributes) return [];

  const confidence = aiAttributes.final_confidence ?? aiAttributes.confidence ?? null;
  const attributesArray = [];

  for (const [key, value] of Object.entries(aiAttributes)) {
    if (key === 'confidence' || key === 'final_confidence') continue;

    attributesArray.push({
      name: key,
      value: value,
      confidence: confidence
    });
  }

  return attributesArray;
};

/**
 * Maps the raw AI colors JSON object to the array format expected by the Flutter UI.
 * 
 * Expected JSON from Python worker:
 * {
 *   "primary_color": "#cccabf",
 *   "secondary_color": "#9f8e71"
 * }
 */
export const mapAiColorsToFlutter = (aiColors) => {
  if (!aiColors) return [];

  const colorsArray = [];

  if (Array.isArray(aiColors)) {
    for (let i = 0; i < aiColors.length; i++) {
      const color = aiColors[i];
      if (typeof color === 'string') {
        colorsArray.push({
          name: i === 0 ? 'primary_color' : `color_${i}`,
          hex: color
        });
      } else if (typeof color === 'object' && color !== null) {
        colorsArray.push({
          name: color.name || `color_${i}`,
          hex: color.hex
        });
      }
    }
  } else if (typeof aiColors === 'object') {
    for (const [key, value] of Object.entries(aiColors)) {
      if (typeof value === 'string') {
        colorsArray.push({
          name: key,
          hex: value
        });
      } else if (typeof value === 'object' && value !== null) {
        colorsArray.push({
          name: value.name || key,
          hex: value.hex
        });
      }
    }
  }

  return colorsArray;
};

/**
 * Maps the Prisma item_ai_responses array to the history object format.
 */
export const mapAiHistory = (itemAiResponses) => {
  if (!itemAiResponses || itemAiResponses.length === 0) return null;

  const latest = itemAiResponses[0];
  return {
    provider: latest.iair_provider,
    model: latest.iair_model,
    timestamp: latest.iair_created_at,
    rawJson: latest.iair_raw_response
  };
};
