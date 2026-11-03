import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_message.dart';
import '../../../domain/entities/service_order_record.dart';
import '../../../domain/repositories/service_order_repository.dart';
import '../../service_order/widgets/service_order_fields.dart';
import '../../service_order/widgets/service_order_ui.dart';

/// Descarga `GET /:id/pdf` (cualquier estado) y lo abre con el visor del
/// teléfono.
Future<void> openOrderPdf(
    BuildContext context, ServiceOrderRecord order) async {
  final repository = context.read<ServiceOrderRepository>();
  AppMessage.show(context, 'Descargando PDF…');
  try {
    final bytes = await repository.downloadPdf(order.id);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${order.folio}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done && context.mounted) {
      AppMessage.error(context, 'No hay una aplicación para abrir el PDF.');
    }
  } on Failure catch (e) {
    if (context.mounted) AppMessage.error(context, e.message);
  } catch (_) {
    if (context.mounted) {
      AppMessage.error(context, 'No se pudo descargar el PDF.');
    }
  }
}

/// PDF por WhatsApp o correo. Compartir y enviar solo con la orden cerrada o
/// no cumplida (§12).
Future<void> showOrderShareSheet(
  BuildContext context,
  ServiceOrderRecord order,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ServiceOrderColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Cómo compartir el PDF?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Folio ${order.folio}',
                style: const TextStyle(
                  color: ServiceOrderColors.mutedText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _ShareOption(
                icon: Icons.mail_outline,
                color: ServiceOrderColors.accent,
                title: 'Correo electrónico',
                subtitle: 'Envía el PDF hasta a 5 correos',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _shareByEmail(context, order);
                },
              ),
              _ShareOption(
                icon: Icons.chat_outlined,
                color: _whatsAppGreen,
                title: 'WhatsApp',
                subtitle: 'Comparte el enlace del PDF (vigente 7 días)',
                showDivider: false,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _shareByWhatsApp(context, order);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _shareByWhatsApp(
  BuildContext context,
  ServiceOrderRecord order,
) async {
  final repository = context.read<ServiceOrderRepository>();
  final url = await showDialog<String>(
    context: context,
    builder: (_) => _ShareDialog(
      mode: _ShareMode.whatsApp,
      folio: order.folio,
      send: (value) async {
        final link = await repository.shareOrder(order.id, phone: value);
        return link.whatsappUrl ?? link.url;
      },
    ),
  );
  if (url == null || !context.mounted) return;
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    AppMessage.error(context, 'No se pudo abrir WhatsApp');
  }
}

Future<void> _shareByEmail(
  BuildContext context,
  ServiceOrderRecord order,
) async {
  final repository = context.read<ServiceOrderRepository>();
  final message = await showDialog<String>(
    context: context,
    builder: (_) => _ShareDialog(
      mode: _ShareMode.email,
      folio: order.folio,
      send: (value) async {
        final message =
            await repository.sendByEmail(order.id, _ShareDialog.emails(value));
        return message ?? 'PDF enviado por correo.';
      },
    ),
  );
  if (message == null || !context.mounted) return;
  AppMessage.success(context, message);
}

const Color _whatsAppGreen = Color(0xFF34C38F);

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _ShareOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(
                  bottom: BorderSide(color: ServiceOrderColors.divider),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: ServiceOrderColors.mutedText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: ServiceOrderColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}

enum _ShareMode { email, whatsApp }

/// Pide los correos o el teléfono y llama a [send]; devuelve su resultado o
/// `null` si se canceló.
class _ShareDialog extends StatefulWidget {
  final _ShareMode mode;
  final String folio;
  final Future<String> Function(String value) send;

  const _ShareDialog({
    required this.mode,
    required this.folio,
    required this.send,
  });

  static List<String> emails(String value) => value
      .split(RegExp(r'[,;\s]+'))
      .map((email) => email.trim())
      .where((email) => email.isNotEmpty)
      .toList();

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isSending = false;
  String? _error;

  bool get _isEmail => widget.mode == _ShareMode.email;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final text = value?.trim() ?? '';
    if (_isEmail) {
      final emails = _ShareDialog.emails(text);
      if (emails.isEmpty) return 'Ingresa al menos un correo';
      if (emails.length > 5) return 'Máximo 5 correos';
      final invalid = emails.where((e) => Validators.email(e) != null);
      return invalid.isEmpty ? null : 'Correo no válido: ${invalid.first}';
    }
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    return digits.length < 10 || digits.length > 15
        ? 'El teléfono debe tener de 10 a 15 dígitos'
        : null;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      final result = await widget.send(_controller.text.trim());
      if (mounted) Navigator.of(context).pop(result);
    } on Failure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo compartir. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    );

    return Dialog(
      backgroundColor: ServiceOrderColors.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ServiceOrderSectionHeader(
                icon: _isEmail ? Icons.mail_outline : Icons.chat_outlined,
                title:
                    _isEmail ? 'Enviar por correo' : 'Compartir por WhatsApp',
              ),
              const SizedBox(height: 8),
              Text(
                _isEmail
                    ? 'Se enviará el PDF de la orden ${widget.folio}. Separa '
                        'varios correos con coma (máximo 5).'
                    : 'Escribe el teléfono del cliente o déjalo vacío para '
                        'elegir el contacto en WhatsApp.',
                style: const TextStyle(
                  color: ServiceOrderColors.mutedText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _controller,
                enabled: !_isSending,
                autofocus: true,
                keyboardType:
                    _isEmail ? TextInputType.emailAddress : TextInputType.phone,
                textInputAction: TextInputAction.send,
                onFieldSubmitted: (_) => _send(),
                validator: _validate,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                decoration: serviceOrderInputDecoration(
                  hint: _isEmail ? 'correo@ejemplo.com' : '7771234567',
                ).copyWith(
                  prefixIcon: Icon(
                    _isEmail ? Icons.alternate_email : Icons.phone_outlined,
                    color: ServiceOrderColors.mutedText,
                  ),
                  errorStyle: const TextStyle(color: AppColors.error),
                  errorBorder: border,
                  focusedErrorBorder: border,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _isSending
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0x33FFFFFF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _send,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.primaryBlue.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEmail ? 'Enviar' : 'Abrir WhatsApp',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
