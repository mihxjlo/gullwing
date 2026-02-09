import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Pulsing radar animation widget for nearby scanning indication
/// Shows concentric expanding circles with fade effect
class PulsingRadar extends StatefulWidget {
  final bool isActive;
  final double size;
  final Color color;
  final Widget? child;

  const PulsingRadar({
    super.key,
    this.isActive = false,
    this.size = 200,
    this.color = const Color(0xFF22D3EE), // Cyan
    this.child,
  });

  @override
  State<PulsingRadar> createState() => _PulsingRadarState();
}

class _PulsingRadarState extends State<PulsingRadar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<AnimationController> _rippleControllers = [];
  final int _rippleCount = 3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Create staggered ripple animations
    for (int i = 0; i < _rippleCount; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      );
      _rippleControllers.add(controller);
    }

    if (widget.isActive) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(PulsingRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  void _startAnimation() {
    // Start ripples with staggered delays
    for (int i = 0; i < _rippleControllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 600), () {
        if (mounted && widget.isActive) {
          _rippleControllers[i].repeat();
        }
      });
    }
  }

  void _stopAnimation() {
    for (final controller in _rippleControllers) {
      controller.stop();
      controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _rippleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple circles
          ..._rippleControllers.asMap().entries.map((entry) {
            return AnimatedBuilder(
              animation: entry.value,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _RipplePainter(
                    progress: entry.value.value,
                    color: widget.color,
                    isActive: widget.isActive,
                  ),
                );
              },
            );
          }),
          // Center widget
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isActive;

  _RipplePainter({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isActive) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;
    
    // Calculate current radius and opacity
    final radius = maxRadius * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.6;

    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isActive != isActive;
  }
}
