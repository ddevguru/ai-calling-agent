import 'dart:async';

import 'package:flutter/material.dart';

import '../api/backend_api.dart';
import '../app_scope.dart';
import '../assistant/assistant_voice_controller.dart';
import '../config.dart';

class VoiceSessionScreen extends StatefulWidget {
  const VoiceSessionScreen({
    super.key,
    this.autoStart = false,
    this.incomingCallerHint,
  });

  final bool autoStart;
  final String? incomingCallerHint;

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen> {
  AssistantVoiceController? _voice;
  var _running = false;
  var _line = '';
  final _log = StringBuffer();
  List<Map<String, dynamic>> _profiles = [];
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadProfiles();
      if (!mounted) return;
      if (widget.autoStart) {
        await _toggle();
      }
    });
  }

  Future<void> _loadProfiles() async {
    final token = AuthScope.of(context).token;
    if (token == null) return;
    try {
      final data = await BackendApi(token).getJson('/api/profiles');
      final list = (data['profiles'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      Map<String, dynamic>? def;
      for (final p in list) {
        if (p['is_default'] == true) def = p;
      }
      setState(() {
        _profiles = list;
        _selected = def ?? (list.isNotEmpty ? list.first : null);
      });
    } catch (e) {
      _log.writeln('profiles: $e');
    }
  }

  @override
  void dispose() {
    final v = _voice;
    _voice = null;
    if (v != null) {
      unawaited(v.stop());
    }
    super.dispose();
  }

  Future<void> _toggle() async {
    final auth = AuthScope.of(context);
    final telecom = TelecomScope.of(context);
    final token = auth.token;
    if (token == null) return;

    if (_running) {
      await _voice?.stop();
      if (!mounted) return;
      setState(() {
        _running = false;
        _voice = null;
        _line = 'idle';
      });
      return;
    }

    final ctrl = AssistantVoiceController(
      telecom: telecom,
      token: token,
      onStatus: (s) {
        if (mounted) setState(() => _line = s);
      },
      onLog: (m) {
        _log.writeln(m);
        if (_log.length > 4000) {
          final t = _log.toString();
          _log.clear();
          _log.write(t.substring(t.length - 3500));
        }
        if (mounted) setState(() {});
      },
    );

    if (!mounted) return;
    setState(() {
      _voice = ctrl;
      _running = true;
      _line = 'starting…';
    });

    await ctrl.start(
      incomingCallerE164: widget.incomingCallerHint,
      profileOverride: _selected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Realtime voice')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Gateway: $kRealtimeUrl',
            style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_profiles.isNotEmpty) ...[
            Text('AI profile', style: t.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selected?['id']?.toString(),
              items: _profiles
                  .map(
                    (p) => DropdownMenuItem(
                      value: p['id']?.toString(),
                      child: Text(p['name']?.toString() ?? ''),
                    ),
                  )
                  .toList(),
              onChanged: _running
                  ? null
                  : (id) {
                      setState(() {
                        _selected = _profiles.firstWhere((e) => e['id']?.toString() == id);
                      });
                    },
              decoration: const InputDecoration(),
            ),
            const SizedBox(height: 18),
          ],
          Text('Status: $_line', style: t.titleMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _toggle,
            child: Text(_running ? 'Stop session' : 'Start session'),
          ),
          const SizedBox(height: 24),
          Text('Log', style: t.titleSmall),
          const SizedBox(height: 8),
          SelectableText(
            _log.isEmpty ? '—' : _log.toString(),
            style: t.bodySmall,
          ),
        ],
      ),
    );
  }
}
