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

  // Structural keys like "primary_color" are storage details, not something a
  // user should read on a colour chip. Resolve those to a real colour name.
  return colorsArray.map((color) => ({
    ...color,
    name: isPlaceholderColorName(color.name)
      ? hexToColorName(color.hex) || color.name
      : color.name,
  }));
};

/** True when a colour's name is a storage key rather than a colour. */
const isPlaceholderColorName = (name) =>
  !name || /^(primary_color|secondary_color|color_\d+)$/.test(name);

/**
 * Human-readable names for the hex values the vision model returns.
 * The model reports colours as hex only, so display strings ("Golden Yellow
 * Dress") are resolved here rather than costing extra tokens in the prompt.
 */
const NAMED_COLORS = [
  ['Black', 0x00, 0x00, 0x00], ['Charcoal', 0x36, 0x45, 0x4f], ['Grey', 0x80, 0x80, 0x80],
  ['Silver', 0xc0, 0xc0, 0xc0], ['Greige', 0xbe, 0xb7, 0xa4], ['Stone', 0x92, 0x8e, 0x85],
  ['White', 0xff, 0xff, 0xff], ['Ivory', 0xff, 0xff, 0xf0], ['Cream', 0xff, 0xfd, 0xd0],
  ['Beige', 0xf5, 0xf5, 0xdc], ['Sand', 0xc2, 0xb2, 0x80], ['Taupe', 0xb3, 0x8b, 0x6d],
  ['Camel', 0xc1, 0x9a, 0x6b], ['Tan', 0xd2, 0xb4, 0x8c], ['Khaki', 0xc3, 0xb0, 0x91],
  ['Brown', 0x8b, 0x45, 0x13], ['Chocolate', 0x7b, 0x3f, 0x00],
  ['Navy', 0x00, 0x00, 0x80], ['Blue', 0x00, 0x00, 0xff], ['Sky Blue', 0x87, 0xce, 0xeb],
  ['Denim Blue', 0x3e, 0x5c, 0x76], ['Steel Blue', 0x46, 0x82, 0xb4],
  ['Cobalt', 0x00, 0x47, 0xab], ['Powder Blue', 0xb0, 0xe0, 0xe6],
  ['Teal', 0x00, 0x80, 0x80], ['Turquoise', 0x40, 0xe0, 0xd0],
  ['Green', 0x00, 0x80, 0x00], ['Emerald', 0x50, 0xc8, 0x78], ['Olive', 0x80, 0x80, 0x00],
  ['Forest Green', 0x22, 0x8b, 0x22], ['Sage', 0x9c, 0xaf, 0x88], ['Mint', 0x98, 0xff, 0x98],
  ['Terracotta', 0xe2, 0x72, 0x5b], ['Mauve', 0xb7, 0x8b, 0xa3], ['Wine', 0x72, 0x2f, 0x37],
  ['Yellow', 0xff, 0xff, 0x00], ['Golden Yellow', 0xff, 0xdf, 0x00], ['Gold', 0xd4, 0xaf, 0x37],
  ['Mustard', 0xff, 0xdb, 0x58], ['Orange', 0xff, 0xa5, 0x00], ['Coral', 0xff, 0x7f, 0x50],
  ['Peach', 0xff, 0xe5, 0xb4], ['Red', 0xff, 0x00, 0x00], ['Crimson', 0xdc, 0x14, 0x3c],
  ['Burgundy', 0x80, 0x00, 0x20], ['Maroon', 0x80, 0x00, 0x00],
  ['Pink', 0xff, 0xc0, 0xcb], ['Blush', 0xde, 0x5d, 0x83], ['Rose', 0xff, 0x00, 0x7f],
  ['Magenta', 0xff, 0x00, 0xff], ['Purple', 0x80, 0x00, 0x80], ['Plum', 0x8e, 0x45, 0x85],
  ['Lavender', 0xe6, 0xe6, 0xfa], ['Lilac', 0xc8, 0xa2, 0xc8],
];

/**
 * Resolves a hex string (e.g. "#cccabf") to the closest human-readable colour
 * name. Returns '' when the value isn't a usable hex colour.
 */
export const hexToColorName = (hex) => {
  if (typeof hex !== 'string') return '';

  let value = hex.trim().replace(/^#/, '');
  if (value.length === 3) {
    value = value.split('').map((ch) => ch + ch).join('');
  }
  if (!/^[0-9a-fA-F]{6}$/.test(value)) return '';

  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);

  let bestName = '';
  let bestDistance = Infinity;

  for (const [name, nr, ng, nb] of NAMED_COLORS) {
    // Weighted RGB distance - approximates perceived difference better than a
    // plain Euclidean distance, which skews towards green.
    const distance = 2 * (r - nr) ** 2 + 4 * (g - ng) ** 2 + 3 * (b - nb) ** 2;
    if (distance < bestDistance) {
      bestDistance = distance;
      bestName = name;
    }
  }

  return bestName;
};

/**
 * Returns the display name of an item's primary colour, accepting either the
 * object shape the worker writes or an already-mapped array.
 */
export const getPrimaryColorName = (aiColors) => {
  const mapped = mapAiColorsToFlutter(aiColors);
  if (mapped.length === 0) return '';

  // mapAiColorsToFlutter already resolves storage keys to real colour names,
  // so the first entry is the primary colour ready for display.
  return mapped[0]?.name ?? '';
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
