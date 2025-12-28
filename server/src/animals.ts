// Animals for pairing codes: <animal><2-digit>
export const ANIMALS = [
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

export function generatePairingCode(): string {
  const animal = ANIMALS[Math.floor(Math.random() * ANIMALS.length)];
  const number = String(Math.floor(Math.random() * 100)).padStart(2, '0');
  return `${animal}${number}`;
}

export function isValidPairingCode(code: string): boolean {
  const match = code.match(/^([a-z]+)(\d{2})$/);
  if (!match) return false;
  return ANIMALS.includes(match[1]);
}
