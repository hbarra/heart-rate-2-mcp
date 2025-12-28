"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.apiRouter = void 0;
const express_1 = require("express");
const store_1 = require("./store");
const animals_1 = require("./animals");
exports.apiRouter = (0, express_1.Router)();
// Receive heart rate reading from mobile app
exports.apiRouter.post('/hr', (req, res) => {
    const { code, bpm, zone } = req.body;
    if (!code || typeof code !== 'string') {
        return res.status(400).json({ error: 'Missing or invalid pairing code' });
    }
    if (!(0, animals_1.isValidPairingCode)(code)) {
        return res.status(400).json({ error: 'Invalid pairing code format' });
    }
    if (typeof bpm !== 'number' || bpm < 30 || bpm > 250) {
        return res.status(400).json({ error: 'Invalid BPM (must be 30-250)' });
    }
    if (typeof zone !== 'number' || zone < 1 || zone > 5) {
        return res.status(400).json({ error: 'Invalid zone (must be 1-5)' });
    }
    (0, store_1.addReading)(code, bpm, zone);
    res.json({ success: true });
});
// Get current heart rate
exports.apiRouter.get('/hr/current', (req, res) => {
    const code = req.query.code;
    if (!code) {
        return res.status(400).json({ error: 'Missing pairing code' });
    }
    if (!(0, animals_1.isValidPairingCode)(code)) {
        return res.status(400).json({ error: 'Invalid pairing code format' });
    }
    const reading = (0, store_1.getCurrentReading)(code);
    if (!reading) {
        return res.json({ data: null });
    }
    res.json({
        data: {
            bpm: reading.bpm,
            zone: reading.zone,
            timestamp: reading.timestamp.toISOString()
        }
    });
});
// Get heart rate history
exports.apiRouter.get('/hr/history', (req, res) => {
    const code = req.query.code;
    const seconds = parseInt(req.query.seconds) || 10;
    if (!code) {
        return res.status(400).json({ error: 'Missing pairing code' });
    }
    if (!(0, animals_1.isValidPairingCode)(code)) {
        return res.status(400).json({ error: 'Invalid pairing code format' });
    }
    if (seconds < 1 || seconds > 1800) {
        return res.status(400).json({ error: 'Seconds must be 1-1800' });
    }
    const readings = (0, store_1.getReadings)(code, seconds);
    res.json({
        data: {
            readings: readings.map(r => ({
                bpm: r.bpm,
                zone: r.zone,
                timestamp: r.timestamp.toISOString()
            }))
        }
    });
});
// Get heart rate stats
exports.apiRouter.get('/hr/stats', (req, res) => {
    const code = req.query.code;
    const seconds = parseInt(req.query.seconds) || 60;
    if (!code) {
        return res.status(400).json({ error: 'Missing pairing code' });
    }
    if (!(0, animals_1.isValidPairingCode)(code)) {
        return res.status(400).json({ error: 'Invalid pairing code format' });
    }
    if (seconds < 1 || seconds > 1800) {
        return res.status(400).json({ error: 'Seconds must be 1-1800' });
    }
    const stats = (0, store_1.getStats)(code, seconds);
    res.json({ data: stats });
});
