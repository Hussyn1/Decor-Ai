const app = require('./src/app');
const connectDB = require('./src/config/db');
const path = require('path');
const express = require('express');
require('dotenv').config();

const PORT = process.env.PORT || 5000;

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

connectDB().then(() => {
    app.listen(PORT, '0.0.0.0', () => {
        console.log(`Server running in ${process.env.NODE_ENV} mode on port ${PORT}`);
    });
}).catch((err) => {
    console.error('DB Connection Failed:', err);
    process.exit(1);
});