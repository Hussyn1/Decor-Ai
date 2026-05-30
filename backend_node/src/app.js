const express = require('express');
const cors = require('cors');

const app = express();

// Middleware
app.use(express.json()); // Body parser
app.use(cors());

// Routes — Single source of truth (do NOT duplicate in server.js)
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/projects', require('./routes/projectRoutes'));
app.use('/api/ai', require('./routes/aiRoutes'));

app.get('/', (req, res) => {
    res.send('API is running...');
});

module.exports = app;
