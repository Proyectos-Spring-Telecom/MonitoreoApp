import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:intl/intl.dart';
import 'package:quickalert/quickalert.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/location_service.dart';

class ServiceReviewPage extends StatefulWidget {
  const ServiceReviewPage({super.key});

  @override
  State<ServiceReviewPage> createState() => _ServiceReviewPageState();
}

class _ServiceReviewPageState extends State<ServiceReviewPage> {
  // Pruebas generadas (checkboxes)
  bool _transmisionCorrecta = true;
  bool _botonPanico = false;
  bool _paroMotorMovilizacion = false;

  // Información adicional
  final _monitoristaController = TextEditingController();
  final _tecnicoController = TextEditingController();
  final _observacionesController = TextEditingController();

  // Firmas
  final SignatureController _clienteSignatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  final SignatureController _tecnicoSignatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  // Fecha, hora y ubicación
  String _fechaHora = '';
  String _lugar = 'Cargando...';

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _monitoristaController.dispose();
    _tecnicoController.dispose();
    _observacionesController.dispose();
    _clienteSignatureController.dispose();
    _tecnicoSignatureController.dispose();
    super.dispose();
  }

  bool _areAllFieldsFilled() {
    final pruebasSelected = _transmisionCorrecta ||
        _botonPanico ||
        _paroMotorMovilizacion;

    final infoFilled = _monitoristaController.text.trim().isNotEmpty &&
        _tecnicoController.text.trim().isNotEmpty;

    final signaturesFilled = _clienteSignatureController.isNotEmpty &&
        _tecnicoSignatureController.isNotEmpty;

    return pruebasSelected && infoFilled && signaturesFilled;
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
            // Pruebas generadas
            _buildSectionTitle('Pruebas generadas:'),
            const SizedBox(height: 16),
            _buildTestsSection(),
            const SizedBox(height: 32),
            // Información adicional
            _buildSectionTitle('Información adicional:'),
            const SizedBox(height: 16),
            _buildAdditionalInfoSection(),
            const SizedBox(height: 32),
            // Firmas
            _buildSignaturesSection(),
            const SizedBox(height: 32),
            // Mensaje de advertencia
            _buildWarningMessage(),
            const SizedBox(height: 16),
            // Información del folio
            _buildOrderInfo(),
            const SizedBox(height: 32),
            // Botón Registrar
            _buildRegisterButton(),
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

  Widget _buildTestsSection() {
    return Column(
      children: [
        _buildCheckboxOption('Transmisión Correcta', _transmisionCorrecta, (value) {
          setState(() => _transmisionCorrecta = value ?? false);
        }),
        const SizedBox(height: 1),
        _buildCheckboxOption('Botón de Pánico', _botonPanico, (value) {
          setState(() => _botonPanico = value ?? false);
        }),
        const SizedBox(height: 1),
        _buildCheckboxOption('Paro de motor y Movilidación', _paroMotorMovilizacion, (value) {
          setState(() => _paroMotorMovilizacion = value ?? false);
        }),
      ],
    );
  }

  Widget _buildCheckboxOption(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
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
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(
          label: 'Monitorista:',
          controller: _monitoristaController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Técnico:',
          controller: _tecnicoController,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'Observaciones:',
          controller: _observacionesController,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
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
          maxLines: maxLines,
          onChanged: (_) => setState(() {}),
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

  Widget _buildSignaturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSignatureField(
          'Firma del Cliente:',
          _clienteSignatureController,
        ),
        const SizedBox(height: 24),
        _buildSignatureField(
          'Firma del Técnico:',
          _tecnicoSignatureController,
        ),
      ],
    );
  }

  Widget _buildSignatureField(String label, SignatureController controller) {
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
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: AppColors.textFieldBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryRed,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Listener(
              onPointerDown: (_) {
                // Actualizar estado cuando se toca para dibujar
                if (mounted) {
                  setState(() {});
                }
              },
              onPointerMove: (_) {
                // Actualizar estado mientras se dibuja
                if (mounted) {
                  setState(() {});
                }
              },
              onPointerUp: (_) {
                // Actualizar estado cuando termina de dibujar
                if (mounted) {
                  setState(() {});
                }
              },
              child: Stack(
                children: [
                  Signature(
                    controller: controller,
                    backgroundColor: AppColors.textFieldBackground,
                    width: double.infinity,
                    height: 250,
                  ),
                  if (!controller.isNotEmpty)
                    Center(
                      child: Text(
                        'Firma',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              onPressed: () {
                controller.clear();
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Limpiar',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarningMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.yellow,
          width: 1,
        ),
      ),
      child: Text(
        'Revisar la información antes de realizar el registro de la orden de servicio.',
        style: TextStyle(
          color: Colors.yellow[700],
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Folio: 0001 Fecha y Hora: $_fechaHora Lugar: $_lugar',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    final isEnabled = _areAllFieldsFilled();

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isEnabled
            ? () {
                _showConfirmDialog(context);
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
          'Registrar Orden de Servicio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _showConfirmDialog(BuildContext context) async {
    await QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'Confirmar Registro',
      text: '¿Estás seguro de guardar los cambios?',
      confirmBtnText: 'Sí, guardar',
      cancelBtnText: 'Cancelar',
      confirmBtnColor: AppColors.primaryRed,
      backgroundColor: AppColors.backgroundDark,
      titleColor: Colors.white,
      textColor: Colors.white,
      onConfirmBtnTap: () async {
        // Cerrar diálogo de confirmación
        Navigator.of(context).pop();
        
        if (!context.mounted) return;
        
        // Mostrar loading usando showDialog para mejor control
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return PopScope(
              canPop: false,
              child: Dialog(
                backgroundColor: AppColors.backgroundDark,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Guardando...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        
        // Simular guardado (en producción aquí se haría la llamada a la API)
        await Future.delayed(const Duration(seconds: 2));
        
        if (!context.mounted) return;
        
        // Cerrar loading
        Navigator.of(context).pop();
        
        if (!context.mounted) return;
        
        // Mostrar éxito
        await QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: '¡Éxito!',
          text: 'La orden de servicio se ha registrado correctamente',
          confirmBtnText: 'Aceptar',
          confirmBtnColor: AppColors.primaryRed,
          backgroundColor: AppColors.backgroundDark,
          titleColor: Colors.white,
          textColor: Colors.white,
          barrierDismissible: false,
          onConfirmBtnTap: () {
            Navigator.of(context).pop(); // Cerrar alerta de éxito
            if (context.mounted) {
              // Navegar a órdenes realizadas
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/completed-orders',
                (route) => route.isFirst,
              );
            }
          },
        );
      },
    );
  }
}
