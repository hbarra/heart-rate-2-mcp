import 'dart:math';

const List<String> _animals = [
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

String generatePairingCode() {
  final random = Random();
  final animal = _animals[random.nextInt(_animals.length)];
  final number = random.nextInt(100).toString().padLeft(2, '0');
  return '$animal$number';
}
