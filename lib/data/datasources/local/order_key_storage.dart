import '../../../core/utils/uuid.dart';
import 'local_storage.dart';

/// `claveApp` de cada orden: un UUID v4 que se genera una sola vez por orden
/// y se guarda en el teléfono, para que reintentar `iniciar` (p. ej. si se
/// cayó la red o se cerró la App) no cree otra clave (§4).
abstract class OrderKeyStorage {
  /// La clave guardada de [orderId] o una nueva, que queda guardada.
  Future<String> keyFor(String orderId);

  /// La orden ya terminó: su clave ya no se necesita.
  Future<void> remove(String orderId);

  /// Al cerrar sesión.
  Future<void> clear();
}

class OrderKeyStorageImpl implements OrderKeyStorage {
  static const String storageKey = 'service_order_app_keys';

  final LocalStorage localStorage;
  final String Function() generate;

  OrderKeyStorageImpl(this.localStorage, {this.generate = uuidV4});

  Future<Map<String, String>> _read() async {
    try {
      final saved = await localStorage.getMap(storageKey);
      return {
        for (final entry in (saved ?? const {}).entries)
          if (entry.value is String) entry.key: entry.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<String> keyFor(String orderId) async {
    final keys = await _read();
    final existing = keys[orderId];
    if (existing != null && existing.isNotEmpty) return existing;
    final key = generate();
    keys[orderId] = key;
    await localStorage.saveMap(storageKey, keys);
    return key;
  }

  @override
  Future<void> remove(String orderId) async {
    final keys = await _read();
    if (keys.remove(orderId) == null) return;
    await localStorage.saveMap(storageKey, keys);
  }

  @override
  Future<void> clear() => localStorage.remove(storageKey);
}
