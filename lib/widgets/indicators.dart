import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Animated pulse effect for the "Active Pulse" indicator
/// Shows a subtle purple glow when live sync is active
class PulseIndicator extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Color glowColor;
  final double glowRadius;

  const PulseIndicator({
    super.key,
    required this.child,
    this.isActive = true,
    this.glowColor = AppColors.primaryAccent,
    this.glowRadius = 20,
  });

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withAlpha((_animation.value * 80).toInt()),
                blurRadius: widget.glowRadius * _animation.value,
                spreadRadius: (widget.glowRadius / 4) * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Status dot indicator for device status
class StatusDot extends StatelessWidget {
  final bool isActive;
  final double size;

  const StatusDot({
    super.key,
    required this.isActive,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.onlineIndicator : AppColors.idleIndicator,
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.onlineIndicator.withAlpha(102),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// Connection chain icon indicator
class ConnectionIndicator extends StatelessWidget {
  final int deviceCount;
  final bool isConnected;

  const ConnectionIndicator({
    super.key,
    required this.deviceCount,
    this.isConnected = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isConnected 
            ? AppColors.primaryAccent.withAlpha(26)
            : AppColors.cardBorder,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.link_outlined,
            color: isConnected 
                ? AppColors.primaryAccent 
                : AppColors.secondaryText,
            size: 24,
          ),
          if (deviceCount > 0)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    deviceCount.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
