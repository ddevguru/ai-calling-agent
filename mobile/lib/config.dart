/// Production (Render). Local dev: `flutter run --dart-define=API_BASE=http://10.0.2.2:3000`
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://ai-phone-web-kytf.onrender.com',
);

/// WebSocket gateway (`wss://` on Render). Local: `--dart-define=REALTIME_URL=ws://10.0.2.2:4000`
const String kRealtimeUrl = String.fromEnvironment(
  'REALTIME_URL',
  defaultValue: 'wss://ai-phone-realtime-gateway-596h.onrender.com',
);

Uri realtimeUriWithToken(String jwt) {
  final base = Uri.parse(kRealtimeUrl);
  final q = Map<String, String>.from(base.queryParameters);
  q['token'] = jwt;
  return base.replace(queryParameters: q);
}
