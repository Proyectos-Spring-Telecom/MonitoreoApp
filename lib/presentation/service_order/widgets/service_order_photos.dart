import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import 'remote_image.dart';
import 'service_order_ui.dart';

class ServiceOrderPhotoSlot {
  final String id;
  final String label;
  final IconData icon;

  const ServiceOrderPhotoSlot(this.id, this.label, this.icon);
}

class ServiceOrderPhotoGrid extends StatelessWidget {
  static final ImagePicker _picker = ImagePicker();

  final List<ServiceOrderPhotoSlot> slots;
  final Map<String, Uint8List> photos;

  /// Fotos que ya están en el servidor, por clave. Se muestran mientras no
  /// se tome una nueva; no se pueden eliminar, solo reemplazar.
  final Map<String, String> remoteUrls;

  /// Recibe `null` cuando el usuario elimina la foto.
  final void Function(String slotId, Uint8List? bytes) onChanged;
  final int crossAxisCount;
  final double childAspectRatio;

  const ServiceOrderPhotoGrid({
    super.key,
    required this.slots,
    required this.photos,
    required this.onChanged,
    this.remoteUrls = const {},
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.35,
  });

  Future<void> _pickPhoto(
    BuildContext context,
    ServiceOrderPhotoSlot slot,
    ImageSource source,
  ) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (file == null) return;
      onChanged(slot.id, await file.readAsBytes());
    } catch (e) {
      if (context.mounted) {
        showServiceOrderMessage(context, 'No se pudo obtener la fotografía.',
            isError: true);
      }
    }
  }

  void _showOptions(BuildContext context, ServiceOrderPhotoSlot slot) {
    final hasLocal = photos.containsKey(slot.id);
    final hasPhoto = hasLocal || remoteUrls.containsKey(slot.id);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ServiceOrderColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Widget option(IconData icon, String label, VoidCallback onTap,
            {Color color = Colors.white}) {
          return ListTile(
            leading: Icon(icon, color: color),
            title: Text(label, style: TextStyle(color: color)),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onTap();
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    slot.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                option(
                  Icons.photo_camera_outlined,
                  hasPhoto ? 'Volver a tomar foto' : 'Tomar foto',
                  () => _pickPhoto(context, slot, ImageSource.camera),
                ),
                option(
                  Icons.photo_library_outlined,
                  'Elegir de la galería',
                  () => _pickPhoto(context, slot, ImageSource.gallery),
                ),
                if (hasLocal)
                  option(
                    Icons.delete_outline,
                    'Eliminar foto',
                    () => onChanged(slot.id, null),
                    color: AppColors.error,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: childAspectRatio,
      children: [
        for (final slot in slots)
          _PhotoTile(
            slot: slot,
            bytes: photos[slot.id],
            remoteUrl: remoteUrls[slot.id],
            onTap: () => _showOptions(context, slot),
          ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final ServiceOrderPhotoSlot slot;
  final Uint8List? bytes;
  final String? remoteUrl;
  final VoidCallback onTap;

  const _PhotoTile({
    required this.slot,
    required this.bytes,
    required this.onTap,
    this.remoteUrl,
  });

  @override
  Widget build(BuildContext context) {
    final photo = bytes;
    final url = remoteUrl;

    return GestureDetector(
      onTap: onTap,
      child: photo == null && url == null
          ? CustomPaint(
              foregroundPainter: const _DashedBorderPainter(
                color: Color(0x66FFFFFF),
                radius: 14,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: ServiceOrderColors.tile,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxHeight < 100;
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          slot.icon,
                          color: const Color(0x99FFFFFF),
                          size: isCompact ? 26 : 32,
                        ),
                        SizedBox(height: isCompact ? 6 : 10),
                        Flexible(
                          child: Text(
                            slot.label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ServiceOrderColors.mutedText,
                              fontSize: isCompact ? 13 : 14,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photo != null)
                    Image.memory(photo, fit: BoxFit.cover)
                  else
                    RemoteImage(url!),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.5, 1.0],
                        colors: [Color(0x00000000), Color(0xCC000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: Text(
                      slot.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.success,
                      child: Icon(Icons.check, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        rect.deflate(0.75),
        Radius.circular(radius),
      ));

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
