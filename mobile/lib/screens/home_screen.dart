import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_scope.dart';
import '../config.dart';
import 'contacts_sync_screen.dart';
import 'profiles_list_screen.dart';
import 'voice_session_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  var _index = 0;
  StreamSubscription<Map<String, dynamic>>? _teleSub;
  final _dial = TextEditingController();
  var _screening = false;
  var _defaultDialer = false;
  String? _line;
  var _calls = const <Map<String, Object?>>[];
  var _lastIncomingVoiceMs = 0;

  static const _launchStartVoice = 'start_voice';
  static const _launchPromptIncoming = 'prompt_incoming';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshTelecomStatus();
      _listenTelecom();
      _loadCalls();
      _consumePendingLaunch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teleSub?.cancel();
    _dial.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _consumePendingLaunch();
    }
  }

  Future<void> _consumePendingLaunch() async {
    if (!mounted) return;
    final telecom = TelecomScope.of(context);
    final raw = await telecom.consumePendingLaunch();
    final action = raw['action']?.toString();
    final handle = raw['handle']?.toString();
    if (!mounted) return;
    if (action == _launchStartVoice) {
      await _launchIncomingVoice(handle);
    } else if (action == _launchPromptIncoming) {
      await _promptIncoming(handle ?? 'Unknown');
    }
  }

  Future<void> _launchIncomingVoice(String? handle) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastIncomingVoiceMs < 2800) return;
    _lastIncomingVoiceMs = now;
    if (!mounted) return;
    final auth = AuthScope.of(context);
    if (auth.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in so Aura can run the AI voice session.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VoiceSessionScreen(
          autoStart: true,
          incomingCallerHint: handle,
        ),
      ),
    );
  }

  Future<void> _refreshTelecomStatus() async {
    final telecom = TelecomScope.of(context);
    final screening = await telecom.isCallScreeningRoleHeld();
    final dialer = await telecom.isDefaultDialer();
    final line = await telecom.getSimLineNumber();
    if (!mounted) return;
    setState(() {
      _screening = screening;
      _defaultDialer = dialer;
      _line = line;
    });
  }

  void _listenTelecom() {
    final telecom = TelecomScope.of(context);
    _teleSub = telecom.events.listen((evt) async {
      final type = evt['type']?.toString();
      if (type == 'incoming') {
        final handle = evt['handle']?.toString() ?? 'Unknown';
        await _promptIncoming(handle);
      }
      if (type == 'incoming_answered') {
        final handle = evt['handle']?.toString();
        await _launchIncomingVoice(handle);
      }
    });
  }

  Future<void> _promptIncoming(String handle) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Incoming call'),
          content: Text('Answer with Aura AI for $handle?'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await TelecomScope.of(context).rejectRingingCall();
              },
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await TelecomScope.of(context).requestAnswerWithAi();
                if (!mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Connecting… If nothing happens, set Aura as the default Phone app (dialer).',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Answer with AI'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.phone,
      Permission.microphone,
      Permission.contacts,
      Permission.notification,
    ].request();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Permissions updated')),
    );
  }

  Future<void> _loadCalls() async {
    final token = AuthScope.of(context).token;
    if (token == null) return;
    final uri = Uri.parse('$kApiBase/api/calls?limit=30');
    final client = HttpClient();
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final resp = await req.close();
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode >= 400) return;
      final data = jsonDecode(text) as Map<String, dynamic>;
      final list = (data['calls'] as List<dynamic>? ?? [])
          .map((e) => Map<String, Object?>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() => _calls = list);
    } catch (_) {
      /* ignore offline */
    } finally {
      client.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final telecom = TelecomScope.of(context);
    final pages = [
      _AssistantPage(
        screening: _screening,
        defaultDialer: _defaultDialer,
        line: _line,
        onRefresh: _refreshTelecomStatus,
        onScreeningRole: () async {
          await telecom.requestCallScreeningRole();
        },
        onDialerRole: () async {
          await telecom.requestDefaultDialerRole();
        },
        onPermissions: _requestPermissions,
        onOpenVoiceSession: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const VoiceSessionScreen()),
          );
        },
      ),
      _DialPage(
        dial: _dial,
        onCall: () async {
          final n = _dial.text.trim();
          if (n.isEmpty) return;
          await telecom.placeCall(n);
        },
      ),
      _HistoryPage(calls: _calls, onRefresh: _loadCalls),
      _SettingsPage(
        onOpenProfiles: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const ProfilesListScreen()),
          );
        },
        onOpenContacts: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const ContactsSyncScreen()),
          );
        },
        onLogout: () async {
          await auth.logout();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signed out')),
          );
        },
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Aura'),
          NavigationDestination(icon: Icon(Icons.dialpad), label: 'Dial'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Logs'),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}

class _AssistantPage extends StatelessWidget {
  const _AssistantPage({
    required this.screening,
    required this.defaultDialer,
    required this.line,
    required this.onRefresh,
    required this.onScreeningRole,
    required this.onDialerRole,
    required this.onPermissions,
    required this.onOpenVoiceSession,
  });

  final bool screening;
  final bool defaultDialer;
  final String? line;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onScreeningRole;
  final Future<void> Function() onDialerRole;
  final Future<void> Function() onPermissions;
  final VoidCallback onOpenVoiceSession;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      key: const ValueKey('assistant'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          Text('Assistant', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600))
              .animate()
              .fadeIn(duration: 320.ms)
              .slideY(begin: 0.04, end: 0),
          const SizedBox(height: 8),
          Text(
            'Inbound detection, notifications, programmable answer + realtime voice. Smart call prompts use Groq/Gemini when configured.',
            style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          _StatusCard(
            title: 'Call screening role',
            ok: screening,
            subtitle: screening ? 'Incoming numbers reach Flutter.' : 'Enable to detect inbound.',
            actionLabel: 'Request role',
            onAction: onScreeningRole,
          ),
          const SizedBox(height: 12),
          _StatusCard(
            title: 'Default dialer',
            ok: defaultDialer,
            subtitle: defaultDialer
                ? 'Aura can answer ringing SIM calls and bind InCall UI.'
                : 'Set Aura as the Phone app so incoming calls can be answered for AI.',
            actionLabel: 'Request role',
            onAction: onDialerRole,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SIM line snapshot', style: t.titleMedium),
                  const SizedBox(height: 8),
                  Text(line?.isNotEmpty == true ? line! : 'Unavailable on this build / carrier'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: onRefresh, child: const Text('Refresh status')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Realtime voice', style: t.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Mic → gateway → GPT‑4o Realtime → speaker. Foreground service keeps the session alive while Aura is in the background.',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onOpenVoiceSession,
                      child: const Text('Open voice session'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onPermissions,
            child: const Text('Request phone, mic, contacts'),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.ok,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final bool ok;
  final String subtitle;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: t.titleMedium)),
                Icon(
                  ok ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: ok ? cs.primary : cs.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () async {
                  await onAction();
                },
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialPage extends StatelessWidget {
  const _DialPage({required this.dial, required this.onCall});

  final TextEditingController dial;
  final Future<void> Function() onCall;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      key: const ValueKey('dial'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dial', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: dial,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'E.164 or local (tel:)',
                hintText: '+14155552671',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onCall,
                child: const Text('Call via SIM'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Uses ACTION_CALL — requires CALL_PHONE permission.',
              style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.calls, required this.onRefresh});

  final List<Map<String, Object?>> calls;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      key: const ValueKey('history'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Call logs', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          Expanded(
            child: calls.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet — complete a call to see history.',
                      style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                    itemCount: calls.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final c = calls[i];
                      return Card(
                        child: ListTile(
                          title: Text(c['peer_e164']?.toString() ?? ''),
                          subtitle: Text(
                            '${c['direction'] ?? ''} · ${c['started_at'] ?? ''}',
                          ),
                          trailing: c['summary'] != null
                              ? const Icon(Icons.notes, size: 20)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.onOpenProfiles,
    required this.onOpenContacts,
    required this.onLogout,
  });

  final VoidCallback onOpenProfiles;
  final VoidCallback onOpenContacts;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      key: const ValueKey('settings'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
        children: [
          Text('Settings', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('AI profiles & voices'),
              subtitle: const Text('Edit instructions, voice, and language.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenProfiles,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              title: const Text('Sync contacts'),
              subtitle: const Text('Upload device contacts to /api/contacts.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onOpenContacts,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton(
            onPressed: onLogout,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
