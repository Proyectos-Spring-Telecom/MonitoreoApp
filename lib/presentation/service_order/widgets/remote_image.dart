import 'package:flutter/material.dart';

import 'service_order_ui.dart';

/// Imagen de S3. La URL firmada caduca a los 5 minutos: al recargar la orden
/// llega una nueva.
class RemoteImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const RemoteImage(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ServiceOrderColors.accent,
                ),
              ),
            ),
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: ServiceOrderColors.field,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: ServiceOrderColors.hintText,
          ),
        ),
      ),
    );
  }
}

void showRemoteImagePreview(BuildContext context, String title, String url) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: ServiceOrderColors.card,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: InteractiveViewer(
              child: RemoteImage(url, fit: BoxFit.contain),
            ),
          ),
        ],
      ),
    ),
  );
}
