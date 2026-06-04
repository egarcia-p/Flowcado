const sqlite3 = require('sqlite3').verbose();
const path = require('path');

// Define the path for the database file in the project root
const dbPath = path.resolve(__dirname, '../flowcado.db'); 
const db = new sqlite3.Database(dbPath);

/**
 * Initializes the database and creates the Session table if it doesn't exist.
 */
function initializeDb() {
    db.serialize(() => {
        // Create the Sessions table
        db.run(`CREATE TABLE IF NOT EXISTS sessions (
            session_id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT DEFAULT 'local',
            start_time TEXT NOT NULL,
            end_time TEXT,
            total_duration_minutes INTEGER,
            config_data TEXT,
            status TEXT NOT NULL
        )`, (err) => {
            if (err) {
                console.error("Error creating sessions table:", err.message);
            } else {
                console.log("Sessions table ensured.");
            }
        });
    });
}

/**
 * Retrieves all recorded sessions, ordered by start time.
 */
function getAllSessions() {
    return new Promise((resolve, reject) => {
        db.all("SELECT * FROM sessions ORDER BY start_time DESC", [], (err, rows) => {
            if (err) {
                reject(err);
            } else {
                resolve(rows);
            }
        });
    });
}

/**
 * Inserts a new session record into the database.
 */
function logSession(sessionData) {
    return new Promise((resolve, reject) => {
        const { start_time, end_time, total_duration_minutes, config_data, status } = sessionData;

        db.run(`INSERT INTO sessions (start_time, end_time, total_duration_minutes, config_data, status) 
                VALUES (?, ?, ?, ?, ?)`, 
            [start_time, end_time, total_duration_minutes, JSON.stringify(config_data), status], 
            function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve({ id: this.lastID });
                }
            });
    });
}

// Initialize the database when the module is required
initializeDb();

module.exports = {
    getAllSessions,
    logSession
};