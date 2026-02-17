const express = require('express');
const router = express.Router();
const {
    registerUser,
    loginUser,
    getMe,
    uploadProfilePicture,
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');
const upload = require('../middleware/uploadMiddleware');

router.post('/signup', registerUser);
router.post('/login', loginUser);
router.get('/me', protect, getMe);
router.post('/upload-profile-picture', protect, upload.single('profilePicture'), uploadProfilePicture);

module.exports = router;
