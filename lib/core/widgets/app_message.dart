import 'dart:async';

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum AppMessageType { info, success, error }

/// Avisos breves en la parte superior de la app. Se dibujan en el overlay
/// raíz, así que siguen visibles al cambiar de pantalla y nunca tapan los
/// botones del pie. Solo hay un aviso a la vez: uno nuevo reemplaza al anterior.
class AppMessage {
  AppMessage._();

  static const Duration _duration = Duration(seconds: 4);

  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    AppMessageType type = AppMessageType.info,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    hide();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppMessageView(
        message: message,
        type: type,
        duration: _duration,
        onDismissed: () {
          if (_current == entry) _current = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void error(BuildContext context, String message) =>
      show(context, message, type: AppMessageType.error);

  static void success(BuildContext context, String message) =>
      show(context, message, type: AppMessageType.success);

  /// Quita el aviso visible sin animación.
  static void hide() {
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _AppMessageView extends StatefulWidget {
  final String message;
  final AppMessageType type;
  final Duration duration;
  final VoidCallback onDismissed;

  const _AppMessageView({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_AppMessageView> createState() => _AppMessageViewState();
}

class _AppMessageViewState extends State<_AppMessageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, -1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    widget.onDismissed();
  }

  (Color, IconData) get _style => switch (widget.type) {
        AppMessageType.error => (AppColors.error, Icons.error_outline),
        AppMessageType.success => (
            AppColors.success,
            Icons.check_circle_outline
          ),
        AppMessageType.info => (const Color(0xFF2B4468), Icons.info_outline),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _controller,
              child: Dismissible(
                key: const ValueKey('app-message'),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  _timer?.cancel();
                  widget.onDismissed();
                },
                child: Semantics(
                  liveRegion: true,
                  child: Material(
                    color: color,
                    elevation: 6,
                    shadowColor: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _close,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Row(
                          children: [
                            Icon(icon, color: Colors.white, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.message,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.close,
                                color: Colors.white70, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
