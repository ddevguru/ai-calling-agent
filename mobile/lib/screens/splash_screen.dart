import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F1419),
              Color(0xFF121A22),
              Color(0xFF151C24),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 72),
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
                    color: const Color(0xFF9AA4B2),
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
