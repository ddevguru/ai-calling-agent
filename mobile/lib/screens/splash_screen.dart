import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../widgets/aura_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.surfaceContainerLowest,
              cs.surface,
              cs.surfaceContainerLow,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Center(
                child: const AuraLogo(size: 108, showRing: true)
                    .animate()
                    .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                    .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
              ),
              const SizedBox(height: 36),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Aura',
                  style: t.displaySmall?.copyWith(
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 420.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.08, end: 0),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Quiet intelligence for your real SIM calls.',
                  style: t.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 120.ms, duration: 520.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.06, end: 0),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 220.ms, duration: 420.ms),
              const SizedBox(height: 56),
            ],
          ),
        ),
      ),
    );
  }
}
