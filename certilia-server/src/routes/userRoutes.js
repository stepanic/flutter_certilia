import { Router } from 'express';
import { authenticate } from '../middleware/auth.js';
import { getExtendedUserInfo } from '../controllers/userController.js';

const router = Router();

// Get extended user information from Certilia
router.get('/extended-info', authenticate, getExtendedUserInfo);

export default router;