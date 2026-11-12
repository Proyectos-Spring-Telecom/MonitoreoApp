import 'package:flutter_test/flutter_test.dart';
import 'package:monitoreo/core/utils/mexico_time.dart';

void main() {
  test('la hora de pared es la de la Ciudad de México (UTC−6)', () {
    final wall = MexicoCityTime.from(DateTime.utc(2026, 10, 28, 21, 40));
    expect([wall.day, wall.hour, wall.minute], [28, 15, 40]);
  });

  test('cerca de la medianoche cambia al día de la Ciudad de México', () {
    final wall = MexicoCityTime.from(DateTime.utc(2026, 10, 29, 3, 5));
    expect([wall.day, wall.hour, wall.minute], [28, 21, 5]);
  });

  test('no depende de la zona horaria del celular', () {
    final instant = DateTime.utc(2026, 1, 2, 6, 0);
    expect(
        MexicoCityTime.from(instant.toLocal()), MexicoCityTime.from(instant));
    expect(MexicoCityTime.from(instant).hour, 0);
  });

  test('el API manda hora de México con Z; un desfase explícito se respeta',
      () {
    expect(
      MexicoCityTime.parseApi('2026-10-30T10:00:00.000Z'),
      DateTime.utc(2026, 10, 30, 16),
    );
    expect(
      MexicoCityTime.parseApi('2026-10-30T10:00:00-06:00'),
      DateTime.utc(2026, 10, 30, 16),
    );
    expect(MexicoCityTime.parseApi('no es fecha'), isNull);
    expect(MexicoCityTime.parseApi(null), isNull);
  });
}
