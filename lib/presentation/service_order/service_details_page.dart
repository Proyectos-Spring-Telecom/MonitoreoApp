import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ServiceDetailsPage extends StatefulWidget {
  const ServiceDetailsPage({super.key});

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage> {
  // Tipo de Servicio (checkboxes)
  bool _instalacion = true;
  bool _revision = false;
  bool _cSim = false;
  bool _cEquipo = false;
  bool _desinstalacion = false;

  // Vehículo cuenta con (toggles)
  bool _botonPanico = false;
  bool _inmovilizador = false;
  bool _regulador = false;
  bool _estereo = false;
  bool _alarma = false;

  // Funcionamiento del vehículo (toggles)
  bool _tableroCorrectoIniciar = false;
  bool _tableroCorrectoFinal = false;
  bool _unidadCorrectaIniciar = false;
  bool _unidadCorrectaFinal = false;

  // Fallas encontradas del equipo (toggles)
  bool _mojado = false;
  bool _golpeado = false;
  bool _cablesCortados = false;
  bool _cablesDesconectados = false;
  bool _otro = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Orden de Servicio',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tipo de Servicio
            _buildSectionTitle('Tipo de Servicio:'),
            const SizedBox(height: 16),
            _buildServiceTypeSection(),
            const SizedBox(height: 32),
            const Divider(color: Colors.white24),
            const SizedBox(height: 32),
            // Vehículo cuenta con
            _buildSectionTitle('Vehículo cuenta con:'),
            const SizedBox(height: 16),
            _buildVehicleFeaturesSection(),
            const SizedBox(height: 32),
            const Divider(color: Colors.white24),
            const SizedBox(height: 32),
            // Funcionamiento del vehículo
            _buildSectionTitle('Funcionamiento del vehículo:'),
            const SizedBox(height: 16),
            _buildVehicleOperationSection(),
            const SizedBox(height: 32),
            const Divider(color: Colors.white24),
            const SizedBox(height: 32),
            // Fallas encontradas del equipo
            _buildSectionTitle('Fallas encontradas del equipo:'),
            const SizedBox(height: 16),
            _buildEquipmentFailuresSection(),
            const SizedBox(height: 32),
            // Botón Siguiente
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildServiceTypeSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildCheckboxOption('Instalación', _instalacion, (value) {
          setState(() => _instalacion = value ?? false);
        }),
        _buildCheckboxOption('Revisión', _revision, (value) {
          setState(() => _revision = value ?? false);
        }),
        _buildCheckboxOption('C/SIM', _cSim, (value) {
          setState(() => _cSim = value ?? false);
        }),
        _buildCheckboxOption('C/Equipo', _cEquipo, (value) {
          setState(() => _cEquipo = value ?? false);
        }),
        _buildCheckboxOption('Desintalación', _desinstalacion, (value) {
          setState(() => _desinstalacion = value ?? false);
        }),
      ],
    );
  }

  Widget _buildCheckboxOption(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          checkColor: AppColors.backgroundDark,
          fillColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.transparent;
          }),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildVehicleFeaturesSection() {
    return Column(
      children: [
        _buildToggleOption('Botón de pánico', _botonPanico, (value) {
          setState(() => _botonPanico = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Inmovilizador', _inmovilizador, (value) {
          setState(() => _inmovilizador = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Regulador', _regulador, (value) {
          setState(() => _regulador = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Estéreo', _estereo, (value) {
          setState(() => _estereo = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Alarma', _alarma, (value) {
          setState(() => _alarma = value);
        }),
      ],
    );
  }

  Widget _buildVehicleOperationSection() {
    return Column(
      children: [
        _buildToggleOption('Tablero correcto al iniciar', _tableroCorrectoIniciar, (value) {
          setState(() => _tableroCorrectoIniciar = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Tablero correcto al final', _tableroCorrectoFinal, (value) {
          setState(() => _tableroCorrectoFinal = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Unidad correcta al iniciar', _unidadCorrectaIniciar, (value) {
          setState(() => _unidadCorrectaIniciar = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Unidad correcta al final', _unidadCorrectaFinal, (value) {
          setState(() => _unidadCorrectaFinal = value);
        }),
      ],
    );
  }

  Widget _buildEquipmentFailuresSection() {
    return Column(
      children: [
        _buildToggleOption('Mojado', _mojado, (value) {
          setState(() => _mojado = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Golpeado', _golpeado, (value) {
          setState(() => _golpeado = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Cables cortados', _cablesCortados, (value) {
          setState(() => _cablesCortados = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Cables desconectados', _cablesDesconectados, (value) {
          setState(() => _cablesDesconectados = value);
        }),
        const SizedBox(height: 16),
        _buildToggleOption('Otro (Especifical en observaciones)', _otro, (value) {
          setState(() => _otro = value);
        }),
      ],
    );
  }

  Widget _buildToggleOption(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primaryRed,
          activeTrackColor: AppColors.primaryRedLight,
          inactiveThumbColor: Colors.grey[600],
          inactiveTrackColor: Colors.grey[800],
        ),
      ],
    );
  }

  bool _areAllSectionsFilled() {
    // Validar Tipo de Servicio: al menos un checkbox seleccionado
    final serviceTypeSelected = _instalacion ||
        _revision ||
        _cSim ||
        _cEquipo ||
        _desinstalacion;

    // Validar Vehículo cuenta con: al menos un toggle activado
    final vehicleFeaturesSelected = _botonPanico ||
        _inmovilizador ||
        _regulador ||
        _estereo ||
        _alarma;

    // Validar Funcionamiento del vehículo: al menos un toggle activado
    final vehicleOperationSelected = _tableroCorrectoIniciar ||
        _tableroCorrectoFinal ||
        _unidadCorrectaIniciar ||
        _unidadCorrectaFinal;

    // Validar Fallas encontradas del equipo: al menos un toggle activado
    final equipmentFailuresSelected = _mojado ||
        _golpeado ||
        _cablesCortados ||
        _cablesDesconectados ||
        _otro;

    return serviceTypeSelected &&
        vehicleFeaturesSelected &&
        vehicleOperationSelected &&
        equipmentFailuresSelected;
  }

  Widget _buildNextButton() {
    final isEnabled = _areAllSectionsFilled();

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled
            ? () {
                Navigator.of(context).pushNamed('/gps-data');
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? AppColors.primaryRed
              : AppColors.primaryRed.withOpacity(0.5),
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryRed.withOpacity(0.5),
          disabledForegroundColor: Colors.white.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Text(
          'Siguiente',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
