const cloudinary = require('cloudinary').v2;
const { CloudinaryStorage } = require('multer-storage-cloudinary');
const multer = require('multer');
const path = require('path');
require('dotenv').config();



cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET
});


const storage = new CloudinaryStorage({
    cloudinary: cloudinary,
    params: {
        folder: 'user_profiles',
        allowed_formats: ['jpg', 'png', 'jpeg', 'webp', 'heic'],
        public_id: (req, file) => 'profile-' + Date.now(),
    },
});


const upload = multer({
    storage: storage,
    limits: { fileSize: 10 * 1024 * 1024 }, 
    fileFilter: function (req, file, cb) {
        
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
