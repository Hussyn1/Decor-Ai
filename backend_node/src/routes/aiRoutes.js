const express = require('express');
const router = express.Router();
const { generate3DModel } = require('../controllers/aiController');
const upload = require('../middleware/uploadMiddleware');



router.post('/generate-3d', upload.single('image'), generate3DModel);

module.exports = router;
