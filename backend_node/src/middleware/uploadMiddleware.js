const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');
const path = require('path');
require('dotenv').config();


// Configure Cloudinary
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});

// Set up Cloudinary storage
const storage = new CloudinaryStorage({
    cloudinary: cloudinary,
    params: {
        folder: 'user_profiles',
        allowed_formats: ['jpg', 'png', 'jpeg', 'webp', 'heic'],
        public_id: (req, file) => 'profile-' + Date.now(),
    },
});

// Init upload
const upload = multer({
    storage: storage,
    limits: { fileSize: 10 * 1024 * 1024 }, // Increased to 10MB for high-res camera photos
    fileFilter: function (req, file, cb) {
        // Redefine checkFileType logic here directly for clarity
        const filetypes = /jpeg|jpg|png|gif|webp|heic/;
        const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
        const mimetype = filetypes.test(file.mimetype) || file.mimetype === 'application/octet-stream';

        if (extname && mimetype) {
            return cb(null, true);
        } else {
            console.log(`Cloudinary Upload Filter Rejected: ${file.originalname}, Mime: ${file.mimetype}`);
            cb(new Error('Images Only! (Supported: jpeg, jpg, png, gif, webp, heic)'));
        }
    }
});

module.exports = upload;
