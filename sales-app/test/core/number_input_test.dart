import 'package:flutter_test/flutter_test.dart';

import 'package:sales_app_mobile/core/number_input.dart';

void main() {
  group('parseNumberInput', () {
    test('angka polos', () {
      expect(parseNumberInput('10000'), 10000);
      expect(parseNumberInput('10'), 10);
      expect(parseNumberInput(''), 0);
    });

    test('pemisah ribuan gaya Indonesia untuk nominal', () {
      expect(parseNumberInput('10.000'), 10000);
      expect(parseNumberInput('1.000.000'), 1000000);
      expect(parseNumberInput('1.500'), 1500);
    });

    test('desimal koma dan titik', () {
      expect(parseNumberInput('10,5'), 10.5);
      expect(parseNumberInput('10.5'), 10.5);
      expect(parseNumberInput('10.000,5'), 10000.5);
      expect(parseNumberInput('10,000.5'), 10000.5);
    });

    test('persen: pemisah tunggal selalu desimal', () {
      expect(parseNumberInput('10.000', allowThousands: false), 10);
      expect(parseNumberInput('2,5', allowThousands: false), 2.5);
      expect(parseNumberInput('2.5', allowThousands: false), 2.5);
    });

    test('karakter non-angka diabaikan', () {
      expect(parseNumberInput('Rp 10.000'), 10000);
      expect(parseNumberInput('  '), 0);
    });

    test('formatEditableNumber membuang .0', () {
      expect(formatEditableNumber(10000.0), '10000');
      expect(formatEditableNumber(2.5), '2.5');
    });
  });
}
