const express = require('express');
const router = express.Router();
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const upload = multer({ storage: multer.memoryStorage() });


const {
    getProjects,
    createProject,
    updateProject,
    deleteProject,
    uploadThumbnail,
} = require('../controllers/projectController');
const { protect } = require('../middleware/authMiddleware');



router.route('/').get(protect, getProjects).post(protect, createProject);
router.route('/:id').put(protect, updateProject).delete(protect, deleteProject);
router.post('/:id/thumbnail', protect, upload.single('thumbnail'), uploadThumbnail);
router.post('/upload-thumbnail-direct', protect, upload.single('thumbnail'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ message: 'No file' });

    const result = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder: 'decor_ar/thumbnails', resource_type: 'image' },
        (error, result) => { if (error) reject(error); else resolve(result); }
      );
      stream.end(req.file.buffer);
    });

    res.status(200).json({ thumbnailUrl: result.secure_url });
  } catch (e) {
    console.error('Direct thumbnail upload error:', e);
    res.status(500).json({ message: e.message });
  }
});

module.exports = router;

