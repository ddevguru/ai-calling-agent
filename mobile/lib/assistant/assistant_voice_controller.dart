import '../api/backend_api.dart';
import '../realtime/realtime_voice_session.dart';
import '../telecom_service.dart';

/// Loads profile + tuned instructions, then runs [RealtimeVoiceSession].
class AssistantVoiceController {
  AssistantVoiceController({
    required this.telecom,
    required this.token,
    this.onStatus,
    this.onLog,
  });

  final TelecomService telecom;
  final String token;
  final void Function(String)? onStatus;
  final void Function(String)? onLog;

  RealtimeVoiceSession? _session;

  Future<void> stop() async {
    await _session?.stop();
    _session = null;
  }

  Future<void> start({
    String? incomingCallerE164,
    Map<String, dynamic>? profileOverride,
  }) async {
    await stop();

    Map<String, dynamic>? selected = profileOverride;
    if (selected == null) {
      try {
        final data = await BackendApi(token).getJson('/api/profiles');
        final list = (data['profiles'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        for (final p in list) {
          if (p['is_default'] == true) selected = p;
        }
        selected ??= list.isNotEmpty ? list.first : null;
      } catch (e) {
        onLog?.call('profiles: $e');
      }
    }

    var instructions = selected?['instructions']?.toString() ??
        'You are a calm phone assistant. Keep replies short and natural.';
    if (incomingCallerE164 != null && incomingCallerE164.isNotEmpty) {
      instructions =
          'You are handling an inbound phone call right now. Caller id hint: $incomingCallerE164. Sound natural and brief unless they open up. $instructions';
    }
    final voice = selected?['voice_id']?.toString() ?? 'marin';
    final lang = selected?['language']?.toString() ?? 'en';

    onStatus?.call('optimizing prompt…');
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
      onLog?.call('call-instructions: $e (using base profile)');
    }

    final session = RealtimeVoiceSession(telecom);
    session.onStatus = onStatus;
    session.onLog = onLog;
    _session = session;

    onStatus?.call('starting…');
    await session.start(
      jwt: token,
      instructions: instructions,
      voice: voice,
      languageHint: lang,
    );
  }
}
