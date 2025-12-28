"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ANIMALS = void 0;
exports.generatePairingCode = generatePairingCode;
exports.isValidPairingCode = isValidPairingCode;
// Animals for pairing codes: <animal><2-digit>
exports.ANIMALS = [
    'tiger',
    'falcon',
    'wolf',
    'eagle',
    'shark',
    'lion',
    'bear',
    'hawk',
    'fox',
    'panther',
    'cobra',
    'raven',
    'lynx',
    'orca',
    'viper',
    'jaguar',
    'condor',
    'badger',
    'raptor',
    'phoenix'
];
function generatePairingCode() {
    const animal = exports.ANIMALS[Math.floor(Math.random() * exports.ANIMALS.length)];
    const number = String(Math.floor(Math.random() * 100)).padStart(2, '0');
    return `${animal}${number}`;
}
function isValidPairingCode(code) {
    const match = code.match(/^([a-z]+)(\d{2})$/);
    if (!match)
        return false;
    return exports.ANIMALS.includes(match[1]);
}
