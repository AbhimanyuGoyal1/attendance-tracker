import 'package:flutter/material.dart';

class InteractiveCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const InteractiveCard({
    super.key,
    required this.child,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.onTap,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final y = _pressed ? 1.5 : (_hovered ? -2.0 : 0.0);
    final elevationAlpha = _pressed ? 0.08 : (_hovered ? 0.16 : 0.10);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: widget.margin,
          transform: Matrix4.translationValues(0, y, 0),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: elevationAlpha),
                blurRadius: _hovered ? 26 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: Material(
              color: Theme.of(context).cardTheme.color,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
