import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class GpsDataPage extends StatefulWidget {
  const GpsDataPage({super.key});

  @override
  State<GpsDataPage> createState() => _GpsDataPageState();
}

class _GpsDataPageState extends State<GpsDataPage> {
  int _selectedTabIndex = 0;

  // Controladores para GPS instalado
  final _nombreEquipoInstaladoController = TextEditingController();
  final _imeiInstaladoController = TextEditingController();
  final _simidInstaladoController = TextEditingController();
  final _telefonoInstaladoController = TextEditingController();

  // Controladores para GPS retirado
  final _nombreEquipoRetiradoController = TextEditingController();
  final _imeiRetiradoController = TextEditingController();
  final _simidRetiradoController = TextEditingController();
  final _telefonoRetiradoController = TextEditingController();

  @override
  void dispose() {
    _nombreEquipoInstaladoController.dispose();
    _imeiInstaladoController.dispose();
    _simidInstaladoController.dispose();
    _telefonoInstaladoController.dispose();
    _nombreEquipoRetiradoController.dispose();
    _imeiRetiradoController.dispose();
    _simidRetiradoController.dispose();
    _telefonoRetiradoController.dispose();
    super.dispose();
  }

  bool _areAllFieldsFilled() {
    if (_selectedTabIndex == 0) {
      // Validar GPS instalado
      return _nombreEquipoInstaladoController.text.trim().isNotEmpty &&
          _imeiInstaladoController.text.trim().isNotEmpty &&
          _simidInstaladoController.text.trim().isNotEmpty &&
          _telefonoInstaladoController.text.trim().isNotEmpty;
    } else {
      // Validar GPS retirado
      return _nombreEquipoRetiradoController.text.trim().isNotEmpty &&
          _imeiRetiradoController.text.trim().isNotEmpty &&
          _simidRetiradoController.text.trim().isNotEmpty &&
          _telefonoRetiradoController.text.trim().isNotEmpty;
    }
  }

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
            // Tabs
            _buildTabs(),
            const SizedBox(height: 24),
            // Contenido de los tabs
            _buildTabContent(),
            const SizedBox(height: 32),
            // Botón Siguiente
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.textFieldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              'Datos del gps instalado',
              0,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              'Datos del gps retirado',
              1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTabIndex == 0) {
      return _buildInstalledGpsTab();
    } else {
      return _buildRemovedGpsTab();
    }
  }

  Widget _buildInstalledGpsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          label: 'Nombre del equipo:',
          controller: _nombreEquipoInstaladoController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'IMEI:',
          controller: _imeiInstaladoController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'SIMID:',
          controller: _simidInstaladoController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Teléfono:',
          controller: _telefonoInstaladoController,
        ),
      ],
    );
  }

  Widget _buildRemovedGpsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          label: 'Nombre del equipo:',
          controller: _nombreEquipoRetiradoController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'IMEI:',
          controller: _imeiRetiradoController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'SIMID:',
          controller: _simidRetiradoController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Teléfono:',
          controller: _telefonoRetiradoController,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: AppColors.textFieldBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    final isEnabled = _areAllFieldsFilled();

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled
            ? () {
                Navigator.of(context).pushNamed('/service-review');
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
