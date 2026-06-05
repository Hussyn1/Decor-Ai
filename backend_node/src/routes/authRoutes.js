const express = require('express');
const router = express.Router();
const {
    registerUser,
    loginUser,
    getMe,
    uploadProfilePicture,
    updateProfile,
    forgotPassword,
    resetPassword,
    changePassword,
    deleteAccount,
    socialLogin,
} = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');
const upload = require('../middleware/uploadMiddleware');

// Public routes
router.post('/signup', registerUser);
router.post('/login', loginUser);
router.post('/forgot-password', forgotPassword);
router.post('/reset-password', resetPassword);
router.post('/social-login', socialLogin);

// Protected routes
router.get('/me', protect, getMe);
router.put('/update-profile', protect, updateProfile);
router.put('/change-password', protect, changePassword);
router.delete('/delete-account', protect, deleteAccount);
router.post('/upload-profile-picture', protect, upload.single('profilePicture'), uploadProfilePicture);

module.exports = router;
