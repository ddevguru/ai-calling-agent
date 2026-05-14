import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../telecom_service.dart';

/// Mic (native PCM16 @ 24kHz) → gateway → OpenAI Realtime; model audio → native speaker.
class RealtimeVoiceSession {
  RealtimeVoiceSession(this.telecom);

  final TelecomService telecom;

  WebSocketChannel? _ch;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<Map<String, dynamic>>? _micSub;

  void Function(String)? onStatus;
  void Function(String)? onLog;

  _SessionConfig? _pendingSession;
  var _sessionUpdateSent = false;
  var _micPipelineStarted = false;

  Future<void> start({
    required String jwt,
    required String instructions,
    required String voice,
    String languageHint = 'en',
  }) async {
    await stop();
    _pendingSession = _SessionConfig(
      instructions: _withLanguage(instructions, languageHint),
      voice: voice,
    );
    _sessionUpdateSent = false;
    _micPipelineStarted = false;

    onStatus?.call('connecting');
    telecom.listenAudio();
    final okSpeaker = await telecom.startSpeaker();
    if (!okSpeaker) {
      onStatus?.call('speaker_failed');
      await telecom.shutdownAudio();
      return;
    }
    _ch = telecom.connectRealtime(jwt);
    _wsSub = _ch!.stream.listen(
      _onWsMessage,
      onError: (_) => onStatus?.call('ws_error'),
      onDone: () => onStatus?.call('ws_closed'),
      cancelOnError: false,
    );
    onStatus?.call('connected');
  }

  String _withLanguage(String instructions, String lang) {
    if (lang.isEmpty || lang == 'en') return instructions;
    return 'Prefer responding in language code "$lang". $instructions';
  }

  void _onWsMessage(dynamic data) {
    final text = data is String
        ? data
        : data is List<int>
            ? utf8.decode(data)
            : null;
    if (text == null) return;

    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final type = msg['type']?.toString() ?? '';

    if (type == 'session.created' && !_sessionUpdateSent) {
      _sessionUpdateSent = true;
      _sendSessionUpdate();
    }
    if (type == 'session.updated' && !_micPipelineStarted) {
      _micPipelineStarted = true;
      unawaited(_startMicPipeline());
    }
    if (type == 'error') {
      onLog?.call(text);
      onStatus?.call('api_error');
    }
    if (type == 'response.output_audio.delta') {
      final delta = msg['delta']?.toString();
      if (delta != null && delta.isNotEmpty) {
        telecom.enqueueSpeakerPcm64(delta);
      }
    }
  }

  void _sendSessionUpdate() {
    final cfg = _pendingSession;
    if (cfg == null) return;
    final payload = {
      'type': 'session.update',
      'session': {
        'type': 'realtime',
        'instructions': cfg.instructions,
        'output_modalities': ['audio'],
        'audio': {
          'input': {
            'format': {'type': 'audio/pcm', 'rate': 24000},
            'turn_detection': {
              'type': 'server_vad',
              'create_response': true,
            },
          },
          'output': {
            'format': {'type': 'audio/pcm', 'rate': 24000},
            'voice': cfg.voice,
          },
        },
      },
    };
    _ch?.sink.add(jsonEncode(payload));
  }

  Future<void> _startMicPipeline() async {
    final micOk = await telecom.startMicStream();
    if (!micOk) {
      onStatus?.call('mic_denied');
      return;
    }
    onStatus?.call('streaming');
    await _micSub?.cancel();
    _micSub = telecom.audioEvents.listen((evt) {
      if (evt['type']?.toString() != 'pcm16') return;
      final b64 = evt['base64']?.toString();
      if (b64 == null || b64.isEmpty) return;
      final frame = jsonEncode({
        'type': 'input_audio_buffer.append',
        'audio': b64,
      });
      _ch?.sink.add(frame);
    });
  }

  Future<void> stop() async {
    await _micSub?.cancel();
    _micSub = null;
    await _wsSub?.cancel();
    _wsSub = null;
    await _ch?.sink.close();
    _ch = null;
    await telecom.stopMicStream();
    await telecom.stopSpeaker();
    await telecom.shutdownAudio();
    _pendingSession = null;
    _sessionUpdateSent = false;
    _micPipelineStarted = false;
    onStatus?.call('idle');
  }
}

class _SessionConfig {
  _SessionConfig({required this.instructions, required this.voice});
  final String instructions;
  final String voice;
}
