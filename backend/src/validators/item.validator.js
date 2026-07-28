import { z } from 'zod';

export const createItemSchema = z.object({
  categoryId: z.number({
    required_error: 'Category ID is required',
    invalid_type_error: 'Category ID must be a number',
  }),
  status: z.string().optional(),
});

export const updateItemSchema = z.object({
  categoryId: z.number().optional(),
  status: z.string().optional(),
  manualAttributes: z.record(z.any()).optional(),
  manualColors: z.record(z.any()).optional(),
  isFavorite: z.boolean().optional(),
});
