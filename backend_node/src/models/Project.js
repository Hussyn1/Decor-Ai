const mongoose = require('mongoose');

const furniturePlacementSchema = new mongoose.Schema({
    modelUri: {
        type: String,
        required: true
    },
    position: {
        type: [Number], // [x, y, z]
        required: true
    },
    rotation: {
        type: [Number], // [x, y, z, w]
        required: true
    },
    scale: {
        type: [Number], // [x, y, z]
        required: true
    },
    cloudAnchorId: {
        type: String,
        default: ''
    }
});

const projectSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    name: {
        type: String,
        required: true
    },
    roomType: {
        type: String,
        required: true
    },
    style: {
        type: String,
        required: true
    },
    thumbnailUrl: {
        type: String,
        default: ''
    },
    items: [furniturePlacementSchema],
    lastModified: {
        type: Date,
        default: Date.now
    }
}, {
    timestamps: true
});

module.exports = mongoose.model('Project', projectSchema);
