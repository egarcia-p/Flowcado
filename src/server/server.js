const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');
const db = require('./db'); // Import our database handler

const app = express();
const PORT = process.env.PORT || 3001; // Support environment port or fallback to 3001

// Middleware setup
app.use(bodyParser.json());

// Serve static assets from 'public' directory
app.use(express.static(path.join(__dirname, 'public')));

// --- API Endpoints ---

/**
 * GET /api/sessions: Retrieves all recorded sessions from the database.
 */
app.get('/api/sessions', async (req, res) => {
    try {
        const sessions = await db.getAllSessions();
        res.json(sessions);
    } catch (error) {
        console.error("Error fetching sessions:", error);
        res.status(500).send({ message: "Failed to retrieve sessions." });
    }
});

/**
 * POST /api/session: Logs a new session record into the database.
 */
app.post('/api/session', async (req, res) => {
    const sessionData = req.body;

    // Basic validation for required fields
    if (!sessionData.start_time || !sessionData.status) {
        return res.status(400).send({ message: "Missing start_time or status." });
    }

    try {
        const result = await db.logSession(sessionData);
        res.status(201).json({ message: "Session logged successfully", id: result.id });
    } catch (error) {
        console.error("Error logging session:", error);
        res.status(500).send({ message: "Failed to log session." });
    }
});

// Start the server
app.listen(PORT, () => {
    console.log(`Flowcado Backend API running on http://localhost:${PORT}`);
});