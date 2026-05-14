/// Point to your machine: Android emulator uses 10.0.2.2 for host localhost.
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://10.0.2.2:3000',
);

/// Full WebSocket URL to the realtime gateway (ws:// or wss://). Token is appended as `?token=`.
/// Render: `wss://your-gateway.onrender.com`
const String kRealtimeUrl = String.fromEnvironment(
  'REALTIME_URL',
  defaultValue: 'ws://10.0.2.2:4000',
);

Uri realtimeUriWithToken(String jwt) {
  final base = Uri.parse(kRealtimeUrl);
  final q = Map<String, String>.from(base.queryParameters);
  q['token'] = jwt;
  return base.replace(queryParameters: q);
}
