const app = require('./src/app');
const connectDB = require('./src/config/db');
const path = require('path');
const express = require('express');
require('dotenv').config();


const PORT = process.env.PORT || 5000;

// Connect to Database
connectDB();



// Serve static uploads folder
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.listen(PORT, () => {
    console.log(`Server running in ${process.env.NODE_ENV} mode on port ${PORT}`);
});
