import { Router } from 'express';
import { verifyFirebaseToken } from '../middleware/auth.js';
import { upload } from '../middleware/upload.js';
import {
  getOutfits,
  createOutfit,
  createOutfitFromPhoto,
  deleteOutfit,
} from '../controllers/outfitController.js';

const router = Router();

router.use(verifyFirebaseToken);

router.get('/', getOutfits);
router.post('/', createOutfit);
router.post('/photo', upload.single('image'), createOutfitFromPhoto);
router.delete('/:id', deleteOutfit);

export default router;
