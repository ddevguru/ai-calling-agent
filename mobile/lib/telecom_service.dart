import 'dart:async';

import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'config.dart';

/// Native telephony + audio bridge — mirrors Kotlin channel names.
class TelecomService {
  static const _methods = MethodChannel('com.aiagentcalling.telecom/methods');
  static const _events = EventChannel('com.aiagentcalling.telecom/events');
  static const _audioEvents = EventChannel('com.aiagentcalling.telecom/audio');

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final _audioController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _controller.stream;
  Stream<Map<String, dynamic>> get audioEvents => _audioController.stream;

  StreamSubscription<dynamic>? _sub;
  StreamSubscription<dynamic>? _audioSub;

  void listen() {
    _sub?.cancel();
    _sub = _events.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final raw = Map<Object?, Object?>.from(event);
          _controller.add(
            raw.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      },
      onError: _controller.addError,
    );
  }

  /// Subscribe before [startMicStream] so PCM chunks are not dropped.
  void listenAudio() {
    _audioSub?.cancel();
    _audioSub = _audioEvents.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final raw = Map<Object?, Object?>.from(event);
          _audioController.add(
            raw.map((k, v) => MapEntry(k.toString(), v)),
          );
        }
      },
      onError: _audioController.addError,
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _audioSub?.cancel();
    await _controller.close();
    await _audioController.close();
  }

  Future<bool> placeCall(String e164) async {
    final ok = await _methods.invokeMethod<bool>('placeCall', {'number': e164});
    return ok ?? false;
  }

  Future<void> openDialer(String e164) async {
    await _methods.invokeMethod('openDialer', {'number': e164});
  }

  Future<String?> getDefaultDialerPackage() async {
    return _methods.invokeMethod<String>('getDefaultDialerPackage');
  }

  Future<bool> requestDefaultDialerRole() async {
    final v = await _methods.invokeMethod<bool>('requestDefaultDialerRole');
    return v ?? false;
  }

  Future<bool> requestCallScreeningRole() async {
    final v = await _methods.invokeMethod<bool>('requestCallScreeningRole');
    return v ?? false;
  }

  Future<bool> isCallScreeningRoleHeld() async {
    final v = await _methods.invokeMethod<bool>('isCallScreeningRoleHeld');
    return v ?? false;
  }

  Future<bool> isDefaultDialer() async {
    final v = await _methods.invokeMethod<bool>('isDefaultDialer');
    return v ?? false;
  }

  Future<String?> getSimLineNumber() async {
    return _methods.invokeMethod<String>('getSimLineNumber');
  }

  Future<void> openAppSettings() async {
    await _methods.invokeMethod('openAppSettings');
  }

  Future<bool> startMicStream() async {
    final v = await _methods.invokeMethod<bool>('startMicStream');
    return v ?? false;
  }

  Future<void> stopMicStream() async {
    await _methods.invokeMethod('stopMicStream');
  }

  Future<bool> startSpeaker() async {
    final v = await _methods.invokeMethod<bool>('startSpeaker');
    return v ?? false;
  }

  Future<void> stopSpeaker() async {
    await _methods.invokeMethod('stopSpeaker');
  }

  Future<void> enqueueSpeakerPcm64(String base64) async {
    await _methods.invokeMethod('enqueueSpeakerPcm64', {'base64': base64});
  }

  Future<void> shutdownAudio() async {
    await _methods.invokeMethod('shutdownAudio');
  }

  WebSocketChannel connectRealtime(String jwt) {
    final uri = realtimeUriWithToken(jwt);
    return WebSocketChannel.connect(uri);
  }
}
