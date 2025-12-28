// In-memory store with 30-minute TTL per reading

export interface HeartRateReading {
  bpm: number;
  zone: number;
  timestamp: Date;
}

interface UserData {
  readings: HeartRateReading[];
}

const TTL_MS = 30 * 60 * 1000; // 30 minutes
const CLEANUP_INTERVAL_MS = 60 * 1000; // Run cleanup every minute

// Map of pairing code -> user data
const store = new Map<string, UserData>();

// Cleanup old readings
function cleanup() {
  const cutoff = new Date(Date.now() - TTL_MS);
  
  for (const [code, data] of store.entries()) {
    data.readings = data.readings.filter(r => r.timestamp > cutoff);
    
    // Remove empty entries
    if (data.readings.length === 0) {
      store.delete(code);
    }
  }
}

// Start cleanup interval
setInterval(cleanup, CLEANUP_INTERVAL_MS);

export function addReading(code: string, bpm: number, zone: number): void {
  let userData = store.get(code);
  
  if (!userData) {
    userData = { readings: [] };
    store.set(code, userData);
  }
  
  userData.readings.push({
    bpm,
    zone,
    timestamp: new Date()
  });
  
  // Also cleanup this user's old readings while we're here
  const cutoff = new Date(Date.now() - TTL_MS);
  userData.readings = userData.readings.filter(r => r.timestamp > cutoff);
}

export function getCurrentReading(code: string): HeartRateReading | null {
  const userData = store.get(code);
  if (!userData || userData.readings.length === 0) {
    return null;
  }
  return userData.readings[userData.readings.length - 1];
}

export function getReadings(code: string, seconds: number): HeartRateReading[] {
  const userData = store.get(code);
  if (!userData) {
    return [];
  }
  
  const cutoff = new Date(Date.now() - seconds * 1000);
  return userData.readings.filter(r => r.timestamp > cutoff);
}

export function getStats(code: string, seconds: number): {
  avg: number;
  min: number;
  max: number;
  count: number;
  timeInZone: Record<number, number>;
} | null {
  const readings = getReadings(code, seconds);
  
  if (readings.length === 0) {
    return null;
  }
  
  const bpms = readings.map(r => r.bpm);
  const avg = Math.round(bpms.reduce((a, b) => a + b, 0) / bpms.length);
  const min = Math.min(...bpms);
  const max = Math.max(...bpms);
  
  // Count readings in each zone
  const timeInZone: Record<number, number> = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  for (const reading of readings) {
    if (reading.zone >= 1 && reading.zone <= 5) {
      timeInZone[reading.zone]++;
    }
  }
  
  // Convert counts to seconds (assuming ~1 reading per second)
  // This is approximate since readings may not be exactly 1Hz
  
  return {
    avg,
    min,
    max,
    count: readings.length,
    timeInZone
  };
}

// For testing: check if a pairing code has any recent activity
export function isActive(code: string): boolean {
  const reading = getCurrentReading(code);
  if (!reading) return false;
  
  // Consider active if reading within last 10 seconds
  return (Date.now() - reading.timestamp.getTime()) < 10000;
}
