import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/location_service.dart';

class ServiceOrderPage extends StatefulWidget {
  const ServiceOrderPage({super.key});

  @override
  State<ServiceOrderPage> createState() => _ServiceOrderPageState();
}

class _ServiceOrderPageState extends State<ServiceOrderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Controladores para datos del cliente
  final _razonSocialController = TextEditingController();
  final _contactoController = TextEditingController();

  // Controladores para datos del vehículo
  final _numeroSerieController = TextEditingController();
  final _motorController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anoController = TextEditingController();
  final _economicoController = TextEditingController();
  final _placaController = TextEditingController();
  final _colorController = TextEditingController();

  // Fecha, hora y ubicación
  String _fechaHora = '';
  String _lugar = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });

    // Agregar listeners para validar campos
    _razonSocialController.addListener(_validateFields);
    _contactoController.addListener(_validateFields);
    _numeroSerieController.addListener(_validateFields);
    _motorController.addListener(_validateFields);
    _marcaController.addListener(_validateFields);
    _modeloController.addListener(_validateFields);
    _anoController.addListener(_validateFields);
    _economicoController.addListener(_validateFields);
    _placaController.addListener(_validateFields);
    _colorController.addListener(_validateFields);

    // Inicializar fecha y hora inmediatamente
    _updateDateTime();

    // Inicializar ubicación
    _initializeLocation();
  }

  void _updateDateTime() {
    final now = DateTime.now();
    try {
      final formatter = DateFormat('EEE dd \'de.\' MMM yyyy', 'es');
      setState(() {
        _fechaHora = formatter.format(now);
      });
    } catch (e) {
      // Si falla el formato con locale, usar formato simple
      final formatter = DateFormat('EEE dd MMM yyyy');
      setState(() {
        _fechaHora = formatter.format(now);
      });
    }
  }

  Future<void> _initializeLocation() async {
    // Obtener ubicación
    final position = await LocationService.getCurrentLocation();
    if (mounted) {
      if (position != null) {
        final locationName = await LocationService.getLocationName(
          position.latitude,
          position.longitude,
        );
        setState(() {
          _lugar = locationName ?? '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        });
      } else {
        setState(() {
          _lugar = 'Ubicación no disponible';
        });
      }
    }
  }

  void _validateFields() {
    setState(() {});
  }

  bool _areAllFieldsFilled() {
    // Validar datos del cliente
    final clientDataFilled = _razonSocialController.text.trim().isNotEmpty &&
        _contactoController.text.trim().isNotEmpty;

    // Validar datos del vehículo
    final vehicleDataFilled = _numeroSerieController.text.trim().isNotEmpty &&
        _motorController.text.trim().isNotEmpty &&
        _marcaController.text.trim().isNotEmpty &&
        _modeloController.text.trim().isNotEmpty &&
        _anoController.text.trim().isNotEmpty &&
        _economicoController.text.trim().isNotEmpty &&
        _placaController.text.trim().isNotEmpty &&
        _colorController.text.trim().isNotEmpty;

    return clientDataFilled && vehicleDataFilled;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _razonSocialController.dispose();
    _contactoController.dispose();
    _numeroSerieController.dispose();
    _motorController.dispose();
    _marcaController.dispose();
    _modeloController.dispose();
    _anoController.dispose();
    _economicoController.dispose();
    _placaController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Información de la orden
            _buildOrderInfo(),
            const SizedBox(height: 32),
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

  Widget _buildOrderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildInfoRow('Folio:', '0001'),
        _buildInfoRow('Fecha y Hora:', _fechaHora.isEmpty ? 'Cargando...' : _fechaHora),
        _buildInfoRow('Lugar:', _lugar),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
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
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ],
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
              'Datos del cliente',
              0,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              'Datos del vehículo',
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
        _tabController.animateTo(index);
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
      return _buildClientDataTab();
    } else {
      return _buildVehicleDataTab();
    }
  }

  Widget _buildClientDataTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          label: 'Razón Social:',
          controller: _razonSocialController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Contacto:',
          controller: _contactoController,
        ),
      ],
    );
  }

  Widget _buildVehicleDataTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          label: 'Numero de serie:',
          controller: _numeroSerieController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Motor:',
          controller: _motorController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Marca:',
          controller: _marcaController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Modelo:',
          controller: _modeloController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Año:',
          controller: _anoController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Económico:',
          controller: _economicoController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Placa:',
          controller: _placaController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Color:',
          controller: _colorController,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
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
          decoration: InputDecoration(
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
                Navigator.of(context).pushNamed('/service-details');
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
