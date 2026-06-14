const axios = require('axios');
const FormData = require('form-data');


const generate3DModel = async (req, res, next) => {
    try {
        
        if (!req.file) {
            return res.status(400).json({
                success: false,
                error: 'Please upload an image file'
            });
        }

        
        const imageUrl = req.file.path;

        console.log(`Downloading image from Cloudinary: ${imageUrl}`);

        
        const imageResponse = await axios.get(imageUrl, {
            responseType: 'arraybuffer',
            timeout: 30000,
        });

        const imageBuffer = Buffer.from(imageResponse.data);
        const filename = imageUrl.split('/').pop() || 'upload.jpg';

        console.log(`Image downloaded (${imageBuffer.length} bytes). Forwarding to AI Service as multipart...`);

        
        const aiServiceUrl = process.env.AI_SERVICE_URL || 'http://localhost:8000';
        const form = new FormData();
        form.append('image', imageBuffer, {
            filename: filename,
            contentType: imageResponse.headers['content-type'] || 'image/jpeg',
        });

        const response = await axios.post(`${aiServiceUrl}/generate-3d`, form, {
            headers: {
                ...form.getHeaders(),
            },
            timeout: 120000, 
        });

        const { task_id, glb_url, message } = response.data;

        res.status(200).json({
            success: true,
            data: {
                taskId: task_id,
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
