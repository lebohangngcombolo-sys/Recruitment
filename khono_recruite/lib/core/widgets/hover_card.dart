import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HoverCard extends StatefulWidget {
  final Widget child;
  final Color? color;

  const HoverCard({super.key, required this.child, this.color});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  final ValueNotifier<bool> _isHovering = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isHovering.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _isHovering.value = true,
      onExit: (_) => _isHovering.value = false,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isHovering,
        builder: (context, isHovering, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.color ?? AppColors.card,
              borderRadius: BorderRadius.circular(5.32),
              border: Border.all(
                color: const Color(0xFF979797),
                width: 1,
              ),
              boxShadow: isHovering
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
