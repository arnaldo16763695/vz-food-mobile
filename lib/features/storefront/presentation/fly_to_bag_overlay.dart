import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Plays the "added to bag" flourish: a shrinking copy of the product image
/// arcs from [source] to the bag icon ([targetKey]) leaving a fading trail so
/// the trajectory is visible. Self-removing; safe to fire and forget.
void flyToBag({
  required BuildContext context,
  required Rect source,
  required GlobalKey targetKey,
  String? imageUrl,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final targetContext = targetKey.currentContext;
  if (overlay == null || targetContext == null) {
    return;
  }

  final targetBox = targetContext.findRenderObject();
  if (targetBox is! RenderBox || !targetBox.hasSize) {
    return;
  }

  final end = targetBox.localToGlobal(targetBox.size.center(Offset.zero));
  final start = source.center;
  if ((end - start).distance < 1) {
    return;
  }

  final startSize = source.shortestSide.clamp(48.0, 96.0);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyToBagAnimation(
      start: start,
      end: end,
      startSize: startSize,
      imageUrl: imageUrl,
      onDone: () {
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );
  overlay.insert(entry);
}

class _FlyToBagAnimation extends StatefulWidget {
  const _FlyToBagAnimation({
    required this.start,
    required this.end,
    required this.startSize,
    required this.imageUrl,
    required this.onDone,
  });

  final Offset start;
  final Offset end;
  final double startSize;
  final String? imageUrl;
  final VoidCallback onDone;

  @override
  State<_FlyToBagAnimation> createState() => _FlyToBagAnimationState();
}

class _FlyToBagAnimationState extends State<_FlyToBagAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Offset _control;

  @override
  void initState() {
    super.initState();

    // Control point above the midpoint so the copy arcs upward before dropping
    // into the bag. Bias it slightly toward the start for a natural swing.
    final mid = Offset(
      (widget.start.dx + widget.end.dx) / 2,
      (widget.start.dy + widget.end.dy) / 2,
    );
    final distance = (widget.end - widget.start).distance;
    final lift = (distance * 0.35).clamp(80.0, 260.0);
    _control = Offset(
      lerpDouble(mid.dx, widget.start.dx, 0.25)!,
      math.min(widget.start.dy, widget.end.dy) - lift,
    );

    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 640),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onDone();
          }
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _pointAt(double t) {
    final u = 1 - t;
    return widget.start * (u * u) +
        _control * (2 * u * t) +
        widget.end * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final raw = _controller.value;
          final t = Curves.easeInOutCubic.transform(raw);
          final pos = _pointAt(t);
          final size = lerpDouble(
            widget.startSize,
            16,
            Curves.easeInQuad.transform(raw),
          )!;
          final opacity = raw < 0.82 ? 1.0 : (1 - (raw - 0.82) / 0.18);

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrailPainter(
                    pointAt: _pointAt,
                    progress: t,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
              Positioned(
                left: pos.dx - size / 2,
                top: pos.dy - size / 2,
                width: size,
                height: size,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: _FlyingChip(size: size, imageUrl: widget.imageUrl),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FlyingChip extends StatelessWidget {
  const _FlyingChip({required this.size, required this.imageUrl});

  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    final radius = size * 0.28;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _ChipFallback(),
              )
            : const _ChipFallback(),
      ),
    );
  }
}

class _ChipFallback extends StatelessWidget {
  const _ChipFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.brandPrimary,
      child: Center(
        child: Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 16),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.pointAt,
    required this.progress,
    required this.color,
  });

  final Offset Function(double t) pointAt;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.02) {
      return;
    }

    const steps = 26;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 1; i <= steps; i++) {
      final headFraction = i / steps; // 0 tail -> 1 head
      final p0 = pointAt(progress * (i - 1) / steps);
      final p1 = pointAt(progress * i / steps);
      paint
        ..color = color.withValues(alpha: 0.05 + 0.32 * headFraction)
        ..strokeWidth = 2 + 6 * headFraction;
      canvas.drawLine(p0, p1, paint);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
