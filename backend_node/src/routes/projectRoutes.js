const express = require('express');
const router = express.Router();
const multer = require('multer');
const {
    getProjects,
    createProject,
    updateProject,
    deleteProject,
    uploadThumbnail,
} = require('../controllers/projectController');
const { protect } = require('../middleware/authMiddleware');

// Use memory storage so we can pipe the buffer directly to Cloudinary
const upload = multer({ storage: multer.memoryStorage() });

router.route('/').get(protect, getProjects).post(protect, createProject);
router.route('/:id').put(protect, updateProject).delete(protect, deleteProject);
router.post('/:id/thumbnail', protect, upload.single('thumbnail'), uploadThumbnail);

module.exports = router;

