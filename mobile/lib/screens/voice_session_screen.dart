import 'package:flutter/material.dart';

import '../api/backend_api.dart';
import '../app_scope.dart';
import '../config.dart';
import '../realtime/realtime_voice_session.dart';

class VoiceSessionScreen extends StatefulWidget {
  const VoiceSessionScreen({super.key});

  @override
  State<VoiceSessionScreen> createState() => _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends State<VoiceSessionScreen> {
  RealtimeVoiceSession? _session;
  var _running = false;
  var _line = '';
  final _log = StringBuffer();
  List<Map<String, dynamic>> _profiles = [];
  Map<String, dynamic>? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfiles());
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
    _session?.stop();
    super.dispose();
  }

  Future<void> _toggle() async {
    final auth = AuthScope.of(context);
    final telecom = TelecomScope.of(context);
    final token = auth.token;
    if (token == null) return;

    if (_running) {
      await _session?.stop();
      setState(() {
        _running = false;
        _session = null;
        _line = 'idle';
      });
      return;
    }

    final p = _selected;
    var instructions = p?['instructions']?.toString() ??
        'You are a calm phone assistant. Keep replies short and natural.';
    final voice = p?['voice_id']?.toString() ?? 'marin';
    final lang = p?['language']?.toString() ?? 'en';

    setState(() => _line = 'optimizing prompt…');
    try {
      final tuned = await BackendApi(token).postJson(
        '/api/assistant/call-instructions',
        {
          'baseInstructions': instructions,
          'language': lang,
        },
      );
      final ins = tuned['instructions']?.toString().trim();
      if (ins != null && ins.isNotEmpty) {
        instructions = ins;
      }
    } catch (e) {
      _log.writeln('call-instructions: $e (using base profile)');
      if (mounted) setState(() {});
    }

    final session = RealtimeVoiceSession(telecom);
    session.onStatus = (s) {
      if (mounted) setState(() => _line = s);
    };
    session.onLog = (m) {
      _log.writeln(m);
      if (_log.length > 4000) {
        final t = _log.toString();
        _log.clear();
        _log.write(t.substring(t.length - 3500));
      }
      if (mounted) setState(() {});
    };

    setState(() {
      _session = session;
      _running = true;
      _line = 'starting…';
    });

    await session.start(
      jwt: token,
      instructions: instructions,
      voice: voice,
      languageHint: lang,
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
            style: t.bodySmall?.copyWith(color: const Color(0xFF9AA4B2)),
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
