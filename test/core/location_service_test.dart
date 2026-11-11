import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:monitoreo/core/services/location_service.dart';

Position _position(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.utc(2026, 11, 11),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// GPS simulado. Por defecto concede el permiso y responde al instante.
class _FakeGeolocator extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.whileInUse;

  /// `null`: el aviso de permiso nunca se contesta.
  LocationPermission? requestAnswer = LocationPermission.whileInUse;

  /// Lo que devuelve `getCurrentPosition`; sin completar = sin señal.
  Future<Position> Function() current = () async => _position(18.92, -99.23);
  Position? lastKnown;
  LocationSettings? settings;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() {
    final answer = requestAnswer;
    return answer == null
        ? Completer<LocationPermission>().future
        : Future.value(answer);
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    settings = locationSettings;
    return current();
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async =>
      lastKnown;
}

void main() {
  late _FakeGeolocator gps;

  setUp(() {
    gps = _FakeGeolocator();
    GeolocatorPlatform.instance = gps;
  });

  /// Corre [getCurrentLocation] avanzando el reloj [elapse].
  Position? readWithClock(Duration elapse) {
    Position? result;
    var done = false;
    fakeAsync((async) {
      LocationService.getCurrentLocation().then((position) {
        result = position;
        done = true;
      });
      async.elapse(elapse);
    });
    expect(done, isTrue, reason: 'debió terminar en $elapse');
    return result;
  }

  test('con señal devuelve la posición y pide un máximo de 15 s', () async {
    final position = await LocationService.getCurrentLocation();
    expect(position?.latitude, 18.92);
    expect(gps.settings?.timeLimit, LocationService.positionTimeout);
    expect(LocationService.positionTimeout, const Duration(seconds: 15));
  });

  test('sin señal a tiempo usa la última posición conocida', () async {
    gps
      ..current = (() => Future.error(TimeoutException('sin señal')))
      ..lastKnown = _position(19.43, -99.13);
    final position = await LocationService.getCurrentLocation();
    expect(position?.latitude, 19.43);
  });

  test('sin señal ni posición conocida devuelve null', () async {
    gps.current = () => Future.error(TimeoutException('sin señal'));
    expect(await LocationService.getCurrentLocation(), isNull);
  });

  test('si el GPS nunca responde, a los 30 s sigue sin ubicación', () {
    gps.current = () => Completer<Position>().future;
    expect(readWithClock(const Duration(seconds: 31)), isNull);
  });

  test('si nadie contesta el aviso de permiso, a los 30 s sigue sin ubicación',
      () {
    gps
      ..permission = LocationPermission.denied
      ..requestAnswer = null;
    expect(readWithClock(const Duration(seconds: 31)), isNull);
  });

  test('antes de los 30 s todavía espera al GPS', () {
    gps.current = () => Completer<Position>().future;
    var done = false;
    fakeAsync((async) {
      LocationService.getCurrentLocation().then((_) => done = true);
      async.elapse(const Duration(seconds: 29));
    });
    expect(done, isFalse);
  });

  test('con el permiso negado devuelve null sin pedir la posición', () async {
    gps
      ..permission = LocationPermission.denied
      ..requestAnswer = LocationPermission.denied;
    expect(await LocationService.getCurrentLocation(), isNull);
    expect(gps.settings, isNull);
  });
}
