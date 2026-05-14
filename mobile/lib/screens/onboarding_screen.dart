import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final Future<void> Function() onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OnboardPage(
        title: 'Your SIM stays in charge',
        body:
            'Outbound calls use your real line. Aura listens for inbound rings and asks before it speaks.',
        icon: Icons.sim_card_outlined,
      ),
      _OnboardPage(
        title: 'Screening that feels calm',
        body:
            'Grant Call Screening and optional default dialer so Aura can see calls and show a gentle prompt.',
        icon: Icons.shield_moon_outlined,
      ),
      _OnboardPage(
        title: 'Realtime voice',
        body:
            'Stream audio through the gateway to GPT‑4o Realtime with the voice and language you pick.',
        icon: Icons.graphic_eq,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => widget.onDone(),
                  child: const Text('Skip'),
                ),
              ],
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: pages
                    .map(
                      (p) => p
                          .animate(key: ValueKey(p.title))
                          .fadeIn(duration: 360.ms, curve: Curves.easeOut)
                          .slideX(begin: 0.03, end: 0),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: i == _index ? 22 : 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF2A3441),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_index < pages.length - 1) {
                      await _controller.nextPage(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutCubic,
                      );
                    } else {
                      await widget.onDone();
                    }
                  },
                  child: Text(_index == pages.length - 1 ? 'Continue' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2430),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A3441)),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 22),
          Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(
            body,
            style: t.bodyLarge?.copyWith(color: const Color(0xFF9AA4B2), height: 1.45),
          ),
        ],
      ),
    );
  }
}
