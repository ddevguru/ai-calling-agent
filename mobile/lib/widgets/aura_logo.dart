import 'package:flutter/material.dart';

/// Brand mark: generated asset on splash; compact variant for headers.
class AuraLogo extends StatelessWidget {
  const AuraLogo({
    super.key,
    this.size = 120,
    this.showRing = true,
  });

  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showRing)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.42),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.secondary.withValues(alpha: 0.28),
                    blurRadius: size * 0.12,
                    spreadRadius: size * 0.02,
                  ),
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: size * 0.78,
              height: size * 0.78,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}
