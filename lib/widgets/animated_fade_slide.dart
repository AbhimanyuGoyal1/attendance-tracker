import 'package:flutter/material.dart';

class AnimatedFadeSlide extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;

  const AnimatedFadeSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.04),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final t = ((value * (duration.inMilliseconds + delay.inMilliseconds)) -
                delay.inMilliseconds) /
            duration.inMilliseconds;
        final p = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(beginOffset.dx * (1 - p), beginOffset.dy * (1 - p) * 100),
            child: child,
          ),
        );
      },
    );
  }
}
