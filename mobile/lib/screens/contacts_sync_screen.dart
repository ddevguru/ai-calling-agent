import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../api/backend_api.dart';
import '../app_scope.dart';

class ContactsSyncScreen extends StatefulWidget {
  const ContactsSyncScreen({super.key});

  @override
  State<ContactsSyncScreen> createState() => _ContactsSyncScreenState();
}

class _ContactsSyncScreenState extends State<ContactsSyncScreen> {
  IsoCode _region = IsoCode.US;
  var _busy = false;
  String? _status;

  static const _regions = <IsoCode>[
    IsoCode.US,
    IsoCode.IN,
    IsoCode.GB,
    IsoCode.DE,
    IsoCode.FR,
    IsoCode.ES,
    IsoCode.IT,
    IsoCode.BR,
    IsoCode.AU,
    IsoCode.CA,
    IsoCode.JP,
    IsoCode.KR,
    IsoCode.CN,
  ];

  Future<void> _sync() async {
    final perm = await Permission.contacts.request();
    if (!perm.isGranted) {
      setState(() => _status = 'Contacts permission denied');
      return;
    }
    final granted = await FlutterContacts.requestPermission();
    if (!granted) {
      setState(() => _status = 'Contacts permission denied');
      return;
    }

    if (!mounted) return;
    final token = AuthScope.of(context).token;
    if (token == null) return;

    setState(() {
      _busy = true;
      _status = 'Reading contacts…';
    });

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final payload = <Map<String, String>>[];

    for (final c in contacts) {
      final name = c.displayName.trim();
      for (final p in c.phones) {
        final raw = p.number.trim();
        if (raw.isEmpty) continue;
        try {
          final parsed = PhoneNumber.parse(raw, callerCountry: _region);
          final e164 = parsed.international.replaceAll(' ', '');
          if (!e164.startsWith('+')) continue;
          payload.add({
            'phoneE164': e164,
            'displayName': name.isEmpty ? e164 : name,
          });
        } catch (_) {
          /* skip unparseable */
        }
      }
    }

    if (payload.isEmpty) {
      setState(() {
        _busy = false;
        _status = 'No valid numbers found for $_region. Try another default region.';
      });
      return;
    }

    setState(() => _status = 'Uploading ${payload.length} numbers…');

    try {
      final api = BackendApi(token);
      await api.putJson('/api/contacts', {'contacts': payload});
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = 'Synced ${payload.length} numbers.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Contact sync')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            'Imports device contacts, parses numbers with the default region you pick, then PUTs to /api/contacts (max 2000 per request — large address books may need batching later).',
            style: t.bodyMedium?.copyWith(color: const Color(0xFF9AA4B2), height: 1.4),
          ),
          const SizedBox(height: 18),
          Text('Default region for parsing', style: t.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<IsoCode>(
            initialValue: _region,
            items: _regions
                .map(
                  (r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.name),
                  ),
                )
                .toList(),
            onChanged: _busy ? null : (v) => setState(() => _region = v ?? IsoCode.US),
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _busy ? null : _sync,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sync to server'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!),
          ],
        ],
      ),
    );
  }
}
