import { Router } from 'express';
import { verifyFirebaseToken } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { createItemSchema, updateItemSchema } from '../validators/item.validator.js';
import { createItem, getItems, getItemById, updateItem, deleteItem, uploadItem, getItemMetadata, replaceItemImage } from '../controllers/itemController.js';
import { upload } from '../middleware/upload.js';

const router = Router();

// All items routes require authentication
router.use(verifyFirebaseToken);

router.post('/upload', upload.single('image'), uploadItem);
router.post('/', validate(createItemSchema), createItem);
router.get('/', getItems);
router.get('/:id/metadata', getItemMetadata);
router.get('/:id', getItemById);
router.put('/:id', validate(updateItemSchema), updateItem);
router.post('/:id/image', upload.single('image'), replaceItemImage);
router.delete('/:id', deleteItem);

export default router;
