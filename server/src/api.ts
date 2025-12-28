import { Router } from 'express';
import { addReading, getCurrentReading, getReadings, getStats } from './store';
import { isValidPairingCode } from './animals';

export const apiRouter = Router();

// Receive heart rate reading from mobile app
apiRouter.post('/hr', (req, res) => {
  const { code, bpm, zone } = req.body;
  
  if (!code || typeof code !== 'string') {
    return res.status(400).json({ error: 'Missing or invalid pairing code' });
  }
  
  if (!isValidPairingCode(code)) {
    return res.status(400).json({ error: 'Invalid pairing code format' });
  }
  
  if (typeof bpm !== 'number' || bpm < 30 || bpm > 250) {
    return res.status(400).json({ error: 'Invalid BPM (must be 30-250)' });
  }
  
  if (typeof zone !== 'number' || zone < 1 || zone > 5) {
    return res.status(400).json({ error: 'Invalid zone (must be 1-5)' });
  }
  
  addReading(code, bpm, zone);
  res.json({ success: true });
});

// Get current heart rate
apiRouter.get('/hr/current', (req, res) => {
  const code = req.query.code as string;
  
  if (!code) {
    return res.status(400).json({ error: 'Missing pairing code' });
  }
  
  if (!isValidPairingCode(code)) {
    return res.status(400).json({ error: 'Invalid pairing code format' });
  }
  
  const reading = getCurrentReading(code);
  
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
apiRouter.get('/hr/history', (req, res) => {
  const code = req.query.code as string;
  const seconds = parseInt(req.query.seconds as string) || 10;
  
  if (!code) {
    return res.status(400).json({ error: 'Missing pairing code' });
  }
  
  if (!isValidPairingCode(code)) {
    return res.status(400).json({ error: 'Invalid pairing code format' });
  }
  
  if (seconds < 1 || seconds > 1800) {
    return res.status(400).json({ error: 'Seconds must be 1-1800' });
  }
  
  const readings = getReadings(code, seconds);
  
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
apiRouter.get('/hr/stats', (req, res) => {
  const code = req.query.code as string;
  const seconds = parseInt(req.query.seconds as string) || 60;
  
  if (!code) {
    return res.status(400).json({ error: 'Missing pairing code' });
  }
  
  if (!isValidPairingCode(code)) {
    return res.status(400).json({ error: 'Invalid pairing code format' });
  }
  
  if (seconds < 1 || seconds > 1800) {
    return res.status(400).json({ error: 'Seconds must be 1-1800' });
  }
  
  const stats = getStats(code, seconds);
  
  res.json({ data: stats });
});
