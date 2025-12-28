export interface HeartRateReading {
    bpm: number;
    zone: number;
    timestamp: Date;
}
export declare function addReading(code: string, bpm: number, zone: number): void;
export declare function getCurrentReading(code: string): HeartRateReading | null;
export declare function getReadings(code: string, seconds: number): HeartRateReading[];
export declare function getStats(code: string, seconds: number): {
    avg: number;
    min: number;
    max: number;
    count: number;
    timeInZone: Record<number, number>;
} | null;
export declare function isActive(code: string): boolean;
