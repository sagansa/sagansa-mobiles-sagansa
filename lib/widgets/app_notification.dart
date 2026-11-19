import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/error_utils.dart';

enum NotificationType { success, error, warning, info }

/// Top floating dynamic capsule notification banner.
/// Slides down from below the top status bar / safe area, floats with a modern
/// squircle card layout, and auto-dismisses or dismisses on swipe up / tap.
/// Ideal for feedback when modal bottom sheets, keyboards, or bottom navigation bars are present.
class AppNotification {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context,
    String message, {
    NotificationType type = NotificationType.info,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopNotificationWidget(
        message: message,
        title: title,
        type: type,
        onDismiss: () {
          _dismissTimer?.cancel();
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      if (_currentEntry == entry) {
        entry.remove();
        _currentEntry = null;
      }
    });
  }

  static void success(BuildContext context, String message, {String? title}) =>
      show(context, message, type: NotificationType.success, title: title);

  static void error(BuildContext context, dynamic message, {String? title}) =>
      show(
        context,
        ErrorUtils.sanitize(message),
        type: NotificationType.error,
        title: title,
      );

  static void warning(BuildContext context, String message, {String? title}) =>
      show(context, message, type: NotificationType.warning, title: title);

  static void info(BuildContext context, String message, {String? title}) =>
      show(context, message, type: NotificationType.info, title: title);
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final String? title;
  final NotificationType type;
  final VoidCallback onDismiss;

  const _TopNotificationWidget({
    required this.message,
    this.title,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.forward();
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (Color, IconData, Color) _getStyle() {
    switch (widget.type) {
      case NotificationType.success:
        return (
          const Color(0xFF1E8E3E),
          Icons.check_circle_rounded,
          const Color(0xFFE6F4EA),
        );
      case NotificationType.error:
        return (
          const Color(0xFFD93025),
          Icons.error_rounded,
          const Color(0xFFFCE8E6),
        );
      case NotificationType.warning:
        return (
          const Color(0xFFE37400),
          Icons.warning_rounded,
          const Color(0xFFFEF7E0),
        );
      case NotificationType.info:
        return (
          const Color(0xFF1A73E8),
          Icons.info_rounded,
          const Color(0xFFE8F0FE),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final (accentColor, icon, bgTint) = _getStyle();

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                _dismiss();
              }
            },
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xF51E293B), // Premium dark slate glass
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title != null) ...[
                            Text(
                              widget.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: widget.title != null
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.white,
                              fontSize: 13,
                              fontWeight: widget.title != null
                                  ? FontWeight.w400
                                  : FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
