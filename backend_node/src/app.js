const express = require('express');
const cors = require('cors');

const app = express();



app.use(express.json()); 
app.use(cors());



app.use('/api/auth', require('./routes/authRoutes'));
app.use('/api/projects', require('./routes/projectRoutes'));
app.use('/api/ai', require('./routes/aiRoutes'));

app.get('/', (req, res) => {
    res.status(200).send('Server is up and running!');
});

module.exports = app;
