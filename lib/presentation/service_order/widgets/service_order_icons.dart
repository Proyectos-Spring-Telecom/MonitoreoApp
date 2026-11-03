import 'package:flutter/material.dart';

import '../../../domain/entities/service_order.dart';

/// Iconos de las opciones del catálogo de órdenes. Las claves nuevas que se
/// agreguen en el servidor usan [fallback].
class ServiceOrderIcons {
  ServiceOrderIcons._();

  static const IconData fallback = Icons.check_box_outlined;

  static const Map<String, IconData> _byKey = {
    'boton_panico': Icons.warning_amber_outlined,
    'inmovilizador': Icons.lock_outline,
    'regulador': Icons.tune,
    'estereo': Icons.speaker_outlined,
    'alarma': Icons.notifications_active_outlined,
    'tablero_iniciar': Icons.dashboard_outlined,
    'tablero_final': Icons.dashboard_customize_outlined,
    'unidad_iniciar': Icons.play_circle_outline,
    'unidad_final': Icons.flag_outlined,
    'mojado': Icons.water_drop_outlined,
    'golpeado': Icons.car_crash_outlined,
    'cables_cortados': Icons.content_cut,
    'cables_desconectados': Icons.power_off_outlined,
    'otro': Icons.more_horiz,
    'transmision': Icons.cell_tower,
    'paro_motor': Icons.power_settings_new,
    'tablero_inicio': Icons.dashboard_outlined,
    'equipo_existente': Icons.gps_fixed,
  };

  static IconData of(String key) =>
      _byKey[key] ??
      (key.startsWith('falla_extra') ? Icons.add_a_photo_outlined : fallback);

  static IconData serviceType(ServiceType type) => switch (type) {
        ServiceType.instalacion => Icons.build_outlined,
        ServiceType.revision => Icons.fact_check_outlined,
        ServiceType.cSim => Icons.sim_card_outlined,
        ServiceType.cEquipo => Icons.memory_outlined,
        ServiceType.desinstalacion => Icons.remove_circle_outline,
      };
}
