const express = require('express');
const cors = require('cors');

const app = express();

// Middleware
app.use(express.json()); // Body parser
app.use(cors());

// Routes
app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/ai', require('./routes/aiRoutes'));

app.get('/', (req, res) => {
    res.send('API is running...');
});

module.exports = app;
