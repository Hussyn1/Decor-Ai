const mongoose = require('mongoose');
const Project = require('../models/Project');

// @desc    Get all user projects
// @route   GET /api/projects
// @access  Private
const getProjects = async (req, res) => {
    try {
        console.log(`GET /api/projects - User: ${req.user.id}`);
        const projects = await Project.find({ user: req.user.id }).sort({ lastModified: -1 });
        console.log(`Found ${projects.length} projects`);
        res.status(200).json(projects);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// @desc    Create a new project
// @route   POST /api/projects
// @access  Private
const createProject = async (req, res) => {
    console.log('POST /api/projects - Body:', JSON.stringify(req.body, null, 2));
    const { name, roomType, style, items, thumbnailUrl } = req.body;

    if (!name || !roomType || !style) {
        console.log('Missing required fields');
        return res.status(400).json({ message: 'Please add all required fields' });
    }

    try {
        const project = await Project.create({
            user: req.user.id,
            name,
            roomType,
            style,
            items: items || [],
            thumbnailUrl: thumbnailUrl || '',
            lastModified: Date.now()
        });
        console.log('Project created successfully:', project._id);
        res.status(201).json(project);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// @desc    Update a project
// @route   PUT /api/projects/:id
// @access  Private
const updateProject = async (req, res) => {
    try {
        console.log(`PUT /api/projects/${req.params.id} - Body items count: ${req.body.items ? req.body.items.length : 0}`);
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
            return res.status(400).json({ message: 'Invalid Project ID format' });
        }

        const project = await Project.findById(req.params.id);

        if (!project) {
            return res.status(404).json({ message: 'Project not found' });
        }

        // Check for user
        if (project.user.toString() !== req.user.id) {
            return res.status(401).json({ message: 'User not authorized' });
        }

        const updatedProject = await Project.findByIdAndUpdate(
            req.params.id,
            { ...req.body, lastModified: Date.now() },
            { new: true }
        );
        console.log('Project updated successfully');
        res.status(200).json(updatedProject);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// @desc    Delete a project
// @route   DELETE /api/projects/:id
// @access  Private
const deleteProject = async (req, res) => {
    try {
        if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
            return res.status(400).json({ message: 'Invalid Project ID format' });
        }
        const project = await Project.findById(req.params.id);

        if (!project) {
            return res.status(404).json({ message: 'Project not found' });
        }

        // Check for user
        if (project.user.toString() !== req.user.id) {
            return res.status(401).json({ message: 'User not authorized' });
        }

        await project.deleteOne();
        res.status(200).json({ id: req.params.id });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

module.exports = {
    getProjects,
    createProject,
    updateProject,
    deleteProject,
};
