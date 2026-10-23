import 'package:flutter_test/flutter_test.dart';
import 'package:company_reg_flutter/utils/saudi_cities_util.dart';

void main() {
  group('saudi_cities_util (Ported Angular Tests)', () {
    group('isSaudiCity', () {
      test('should recognize major Saudi cities in standard English casing', () {
        expect(isSaudiCity('Riyadh'), isTrue);
        expect(isSaudiCity('Jeddah'), isTrue);
        expect(isSaudiCity('Dammam'), isTrue);
        expect(isSaudiCity('Khobar'), isTrue);
        expect(isSaudiCity('Dhahran'), isTrue);
        expect(isSaudiCity('Tabuk'), isTrue);
        expect(isSaudiCity('Taif'), isTrue);
        expect(isSaudiCity('Buraidah'), isTrue);
        expect(isSaudiCity('Jubail'), isTrue);
        expect(isSaudiCity('Abha'), isTrue);
        expect(isSaudiCity('Khamis Mushait'), isTrue);
        expect(isSaudiCity('Hail'), isTrue);
        expect(isSaudiCity('Najran'), isTrue);
        expect(isSaudiCity('Jazan'), isTrue);
        expect(isSaudiCity('Yanbu'), isTrue);
        expect(isSaudiCity('Qatif'), isTrue);
        expect(isSaudiCity('NEOM'), isTrue);
      });

      test('should recognize common transliteration variants and prefixes', () {
        expect(isSaudiCity('riyadh'), isTrue);
        expect(isSaudiCity('ar riyadh'), isTrue);
        expect(isSaudiCity('ar-riyadh'), isTrue);
        expect(isSaudiCity('al khobar'), isTrue);
        expect(isSaudiCity('al-khobar'), isTrue);
        expect(isSaudiCity('makkah'), isTrue);
        expect(isSaudiCity('mecca'), isTrue);
        expect(isSaudiCity('madinah'), isTrue);
        expect(isSaudiCity('medina'), isTrue);
        expect(isSaudiCity('al madinah'), isTrue);
        expect(isSaudiCity('hofuf'), isTrue);
        expect(isSaudiCity('al ahsa'), isTrue);
        expect(isSaudiCity('al-ahsa'), isTrue);
        expect(isSaudiCity('at taif'), isTrue);
        expect(isSaudiCity('buraydah'), isTrue);
        expect(isSaudiCity('jiddah'), isTrue);
      });

      test('should recognize Arabic script city names', () {
        expect(isSaudiCity('الرياض'), isTrue);
        expect(isSaudiCity('جدة'), isTrue);
        expect(isSaudiCity('مكة المكرمة'), isTrue);
        expect(isSaudiCity('الدمام'), isTrue);
      });

      test('should NOT recognize non-Saudi cities (strictly restricted to Saudi Arabia)', () {
        expect(isSaudiCity('London'), isFalse);
        expect(isSaudiCity('New York'), isFalse);
        expect(isSaudiCity('Dubai'), isFalse);
        expect(isSaudiCity('Abu Dhabi'), isFalse);
        expect(isSaudiCity('Paris'), isFalse);
        expect(isSaudiCity('Tokyo'), isFalse);
        expect(isSaudiCity('Chennai'), isFalse);
        expect(isSaudiCity('Mumbai'), isFalse);
        expect(isSaudiCity('Cairo'), isFalse);
      });

      test('should handle null, empty, or whitespace safely', () {
        expect(isSaudiCity(null), isFalse);
        expect(isSaudiCity(''), isFalse);
        expect(isSaudiCity('   '), isFalse);
      });
    });

    group('getCanonicalSaudiCity', () {
      test('should return the canonical name for recognized variations', () {
        expect(getCanonicalSaudiCity('ar-riyadh'), 'Riyadh');
        expect(getCanonicalSaudiCity('al khobar'), 'Khobar');
        expect(getCanonicalSaudiCity('makkah'), 'Mecca');
        expect(getCanonicalSaudiCity('madinah'), 'Medina');
        expect(getCanonicalSaudiCity('al-ahsa'), 'Al-Ahsa');
        expect(getCanonicalSaudiCity('hofuf'), 'Hofuf');
      });

      test('should return null for non-Saudi cities', () {
        expect(getCanonicalSaudiCity('San Francisco'), isNull);
        expect(getCanonicalSaudiCity('Berlin'), isNull);
      });
    });

    group('SAUDI_MAJOR_CITIES', () {
      test('should include prominent economic and administrative hubs', () {
        expect(SAUDI_MAJOR_CITIES, contains('Riyadh'));
        expect(SAUDI_MAJOR_CITIES, contains('Jeddah'));
        expect(SAUDI_MAJOR_CITIES, contains('Dammam'));
        expect(SAUDI_MAJOR_CITIES, contains('Khobar'));
        expect(SAUDI_MAJOR_CITIES, contains('Jubail'));
        expect(SAUDI_MAJOR_CITIES, contains('NEOM'));
      });
    });
  });
}
