const axios = require('axios');
const path = require('path');
const fs = require('fs');

/**
 * Controller for AI Operations
 */
const generate3DModel = async (req, res, next) => {
    try {
        // Check if file was uploaded
        if (!req.file) {
            return res.status(400).json({
                success: false,
                error: 'Please upload an image file'
            });
        }

        // The file path is the Cloudinary URL because we use CloudinaryStorage
        const imageUrl = req.file.path;

        console.log(`Forwarding Cloudinary URL to AI Service: ${imageUrl}`);

        // Call the Python AI Service with the REAL Cloudinary URL
        const aiServiceUrl = process.env.AI_SERVICE_URL || 'http://localhost:8000';

        const response = await axios.post(`${aiServiceUrl}/generate-3d`, {
            image_url: imageUrl
        });

        const { glb_url, message } = response.data;

        res.status(200).json({
            success: true,
            data: {
                glbUrl: glb_url,
                message: message,
                originalImageUrl: imageUrl
            }
        });

    } catch (error) {
        console.error('Error in AI Controller:', error.message);
        res.status(500).json({
            success: false,
            error: error.response?.data?.detail || 'Failed to process image through AI service'
        });
    }
};

module.exports = {
    generate3DModel
};
