import { Router } from 'express';
import { verifyFirebaseToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { createItemSchema, updateItemSchema } from '../validators/item.validator.js';
import { createItem, getItems, getItemById, updateItem, deleteItem } from '../controllers/itemController.js';

const router = Router();

// All items routes require authentication
router.use(verifyFirebaseToken);

router.post('/', validate(createItemSchema), createItem);
router.get('/', getItems);
router.get('/:id', getItemById);
router.put('/:id', validate(updateItemSchema), updateItem);
router.delete('/:id', deleteItem);

export default router;
