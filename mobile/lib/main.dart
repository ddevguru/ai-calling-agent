import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'app_theme.dart';
import 'auth_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/register_screen.dart';
import 'screens/splash_screen.dart';
import 'telecom_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F1419),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  final auth = AuthStore();
  await auth.loadToken();
  final telecom = TelecomService()..listen();
  runApp(AuraApp(auth: auth, telecom: telecom));
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key, required this.auth, required this.telecom});

  final AuthStore auth;
  final TelecomService telecom;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: auth,
      child: TelecomScope(
        telecom: telecom,
        child: MaterialApp(
          title: 'Aura Call',
          debugShowCheckedModeBanner: false,
          theme: buildAuraTheme(),
          home: _RootNavigator(auth: auth),
        ),
      ),
    );
  }
}

class _RootNavigator extends StatefulWidget {
  const _RootNavigator({required this.auth});

  final AuthStore auth;

  @override
  State<_RootNavigator> createState() => _RootNavigatorState();
}

class _RootNavigatorState extends State<_RootNavigator> {
  _Phase _phase = _Phase.splash;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuth);
    _scheduleSplash();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (widget.auth.token == null && _phase == _Phase.home) {
      setState(() => _phase = _Phase.login);
    } else {
      setState(() {});
    }
  }

  Future<void> _scheduleSplash() async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_done') ?? false;
    setState(() {
      if (!done) {
        _phase = _Phase.onboarding;
      } else if (widget.auth.token == null) {
        _phase = _Phase.login;
      } else {
        _phase = _Phase.home;
      }
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    setState(() {
      _phase = widget.auth.token == null ? _Phase.login : _Phase.home;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (_phase) {
        _Phase.splash => SplashScreen(key: const ValueKey('splash')),
        _Phase.onboarding => OnboardingScreen(
            key: const ValueKey('onboarding'),
            onDone: _finishOnboarding,
          ),
        _Phase.login => LoginScreen(
            key: const ValueKey('login'),
            onCreateAccount: () => setState(() => _phase = _Phase.register),
            onSignedIn: () => setState(() => _phase = _Phase.home),
          ),
        _Phase.register => RegisterScreen(
            key: const ValueKey('register'),
            onBack: () => setState(() => _phase = _Phase.login),
            onRegistered: () => setState(() => _phase = _Phase.home),
          ),
        _Phase.home => HomeScreen(key: const ValueKey('home')),
      },
    );
  }
}

enum _Phase { splash, onboarding, login, register, home }
