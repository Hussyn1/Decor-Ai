const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const User = require('../models/User');


const generateToken = (id) => {
    return jwt.sign({ id }, process.env.JWT_SECRET, {
        expiresIn: '30d',
    });
};




const registerUser = async (req, res) => {
    const { username, email, password } = req.body;

    if (!username || !email || !password) {
        return res.status(400).json({ message: 'Please add all fields' });
    }

    try {
        
        const userExists = await User.findOne({ email });
        if (userExists) {
            return res.status(400).json({ message: 'User already exists' });
        }

        
        const user = await User.create({
            username,
            email,
            password,
        });

        if (user) {
            res.status(201).json({
                _id: user.id,
                username: user.username,
                email: user.email,
                profilePicture: user.profilePicture,
                bio: user.bio,
                token: generateToken(user._id),
            });
        } else {
            res.status(400).json({ message: 'Invalid user data' });
        }
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};




const loginUser = async (req, res) => {
    const { email, password } = req.body;

    try {
        
        const user = await User.findOne({ email });

        if (user && (await user.matchPassword(password))) {
            res.json({
                _id: user.id,
                username: user.username,
                email: user.email,
                profilePicture: user.profilePicture,
                bio: user.bio,
                token: generateToken(user._id),
            });
        } else {
            res.status(401).json({ message: 'Invalid credentials' });
        }
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};




const getMe = async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        res.status(200).json({
            id: user._id,
            username: user.username,
            email: user.email,
            profilePicture: user.profilePicture,
            bio: user.bio,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};




const uploadProfilePicture = async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'Please upload a file' });
        }

        const user = await User.findById(req.user.id);

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        
        const profilePictureUrl = req.file.path;

        user.profilePicture = profilePictureUrl;
        await user.save();

        res.status(200).json({
            message: 'Profile picture uploaded successfully',
            profilePicture: user.profilePicture,
        });

    } catch (error) {
        console.error('Profile Picture Upload Error:', error);
        res.status(500).json({
            message: 'Server error during upload',
            error: error.message
        });
    }
};




const updateProfile = async (req, res) => {
    try {
        const user = await User.findById(req.user.id);

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        const { username, email, bio } = req.body;

        
        if (email && email !== user.email) {
            const emailExists = await User.findOne({ email });
            if (emailExists) {
                return res.status(400).json({ message: 'Email already in use by another account' });
            }
        }

        if (username) user.username = username;
        if (email) user.email = email;
        if (bio !== undefined) user.bio = bio;

        await user.save();

        res.status(200).json({
            _id: user.id,
            username: user.username,
            email: user.email,
            profilePicture: user.profilePicture,
            bio: user.bio,
            token: generateToken(user._id),
        });
    } catch (error) {
        console.error('Update Profile Error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};




const forgotPassword = async (req, res) => {
    try {
        const { email } = req.body;

        if (!email) {
            return res.status(400).json({ message: 'Please provide an email address' });
        }

        const user = await User.findOne({ email });

        if (!user) {
            
            return res.status(200).json({ message: 'If an account with that email exists, a reset code has been sent.' });
        }

        
        const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
        const hashedToken = crypto.createHash('sha256').update(resetCode).digest('hex');

        user.resetPasswordToken = hashedToken;
        user.resetPasswordExpire = Date.now() + 15 * 60 * 1000; 
        await user.save();

        console.log(`[AUTH] Password reset code for ${user.email} is: ${resetCode}`);

        
        if (process.env.EMAIL_USER && process.env.EMAIL_PASS) {
            try {
                
                const nodemailer = require('nodemailer');

                const transporter = nodemailer.createTransport({
                    service: 'gmail',
                    auth: {
                        user: process.env.EMAIL_USER,
                        pass: process.env.EMAIL_PASS,
                    },
                });

                const mailOptions = {
                    from: `"Decor AI" <${process.env.EMAIL_USER}>`,
                    to: user.email,
                    subject: 'Decor AI — Password Reset Code',
                    html: `
                        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
                            <h2 style="color: #4A90D9;">Password Reset</h2>
                            <p>Hi <strong>${user.username}</strong>,</p>
                            <p>You requested a password reset for your Decor AI account.</p>
                            <p>Your password reset code is:</p>
                            <div style="background: #f0f4ff; padding: 16px; border-radius: 8px; text-align: center; margin: 20px 0;">
                                <code style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #4A90D9;">${resetCode}</code>
                            </div>
                            <p style="color: #666;">This code expires in 15 minutes.</p>
                            <p style="color: #999; font-size: 12px;">If you didn't request this, please ignore this email.</p>
                        </div>
                    `,
                };

                await transporter.sendMail(mailOptions);
                console.log(`[AUTH] Password reset email successfully sent to ${user.email}`);
            } catch (mailError) {
                console.error('Nodemailer Error: Failed to send email:', mailError.message);
                
                console.log(`[FALLBACK CODE FOR DEV] Reset Code: ${resetCode}`);
            }
        } else {
            console.log(`[NO EMAIL CONFIG] SMTP credentials not set. Reset Code for ${user.email}: ${resetCode}`);
        }

        res.status(200).json({
            message: 'If an account with that email exists, a reset code has been sent.',
        });
    } catch (error) {
        console.error('Forgot Password Error:', error);
        res.status(500).json({ message: 'Failed to send reset email. Please try again later.' });
    }
};




const resetPassword = async (req, res) => {
    try {
        const { email, code, newPassword } = req.body;

        if (!email || !code || !newPassword) {
            return res.status(400).json({ message: 'Please provide email, code, and new password' });
        }

        if (newPassword.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters' });
        }

        const user = await User.findOne({ email });

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        
        const hashedToken = crypto.createHash('sha256').update(code.trim()).digest('hex');

        if (user.resetPasswordToken !== hashedToken || user.resetPasswordExpire < Date.now()) {
            return res.status(400).json({ message: 'Invalid or expired password reset code' });
        }

        
        user.password = newPassword;
        user.resetPasswordToken = undefined;
        user.resetPasswordExpire = undefined;
        await user.save();

        res.status(200).json({ message: 'Password reset successful' });
    } catch (error) {
        console.error('Reset Password Error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};




const changePassword = async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;

        if (!currentPassword || !newPassword) {
            return res.status(400).json({ message: 'Please provide both current and new password' });
        }

        if (newPassword.length < 6) {
            return res.status(400).json({ message: 'New password must be at least 6 characters' });
        }

        const user = await User.findById(req.user.id);

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        
        const isMatch = await user.matchPassword(currentPassword);
        if (!isMatch) {
            return res.status(401).json({ message: 'Current password is incorrect' });
        }

        user.password = newPassword; 
        await user.save();

        res.status(200).json({ message: 'Password changed successfully' });
    } catch (error) {
        console.error('Change Password Error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};




const deleteAccount = async (req, res) => {
    try {
        const user = await User.findById(req.user.id);

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        await User.findByIdAndDelete(req.user.id);

        res.status(200).json({ message: 'Account deleted successfully' });
    } catch (error) {
        console.error('Delete Account Error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};




const socialLogin = async (req, res) => {
    try {
        const { provider, email, username } = req.body;

        if (!email || !provider) {
            return res.status(400).json({ message: 'Email and provider are required' });
        }

        
        let user = await User.findOne({ email });

        if (!user) {
            
            const randomPassword = crypto.randomBytes(16).toString('hex');
            user = await User.create({
                username: username || email.split('@')[0],
                email,
                password: randomPassword,
            });
        }

        res.status(200).json({
            _id: user.id,
            username: user.username,
            email: user.email,
            profilePicture: user.profilePicture,
            bio: user.bio,
            token: generateToken(user._id),
        });
    } catch (error) {
        console.error('Social Login Error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

module.exports = {
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
};
