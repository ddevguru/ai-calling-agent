import 'package:flutter/material.dart';

import '../app_scope.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onCreateAccount, required this.onSignedIn});

  final VoidCallback onCreateAccount;
  final VoidCallback onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AuthScope.of(context);
    try {
      await auth.login(
        phoneE164: _phone.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      widget.onSignedIn();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          children: [
            Text('Welcome back', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Sign in with your phone (E.164) and password.',
              style: t.bodyMedium?.copyWith(color: const Color(0xFF9AA4B2)),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (+E.164)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFB9A6A1))),
            ],
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: widget.onCreateAccount,
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}
