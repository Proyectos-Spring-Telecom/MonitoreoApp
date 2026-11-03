import 'package:flutter_test/flutter_test.dart';
import 'package:monitoreo/core/utils/mexico_time.dart';

void main() {
  test('formatea en español y en hora de la Ciudad de México (UTC−6)', () {
    expect(
      MexicoCityTime.format(DateTime.utc(2026, 10, 28, 21, 40)),
      '28 de octubre de 2026, 15:40 h',
    );
  });

  test('cerca de la medianoche cambia al día de la Ciudad de México', () {
    expect(
      MexicoCityTime.format(DateTime.utc(2026, 10, 29, 3, 5)),
      '28 de octubre de 2026, 21:05 h',
    );
  });

  test('no depende de la zona horaria del celular', () {
    final instant = DateTime.utc(2026, 1, 2, 6, 0);
    expect(MexicoCityTime.format(instant.toLocal()),
        MexicoCityTime.format(instant));
    expect(MexicoCityTime.format(instant), '2 de enero de 2026, 00:00 h');
  });
}
