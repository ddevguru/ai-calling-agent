import 'package:flutter/material.dart';

import '../api/backend_api.dart';
import '../app_scope.dart';
import '../constants/realtime_options.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _instructions;
  late String _voice;
  late String _language;
  var _isDefault = false;
  var _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name']?.toString() ?? '');
    _instructions = TextEditingController(
      text: e?['instructions']?.toString() ??
          'You answer phone calls politely and concisely on behalf of the user.',
    );
    _voice = e?['voice_id']?.toString() ?? 'alloy';
    _language = e?['language']?.toString() ?? 'en';
    _isDefault = e?['is_default'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = AuthScope.of(context).token;
    if (token == null) return;
    setState(() => _saving = true);
    final api = BackendApi(token);
    try {
      if (_isEdit) {
        final id = widget.existing!['id']?.toString();
        await api.patchJson('/api/profiles/$id', {
          'name': _name.text.trim(),
          'instructions': _instructions.text.trim(),
          'voiceId': _voice,
          'language': _language,
          'isDefault': _isDefault,
        });
      } else {
        await api.postJson('/api/profiles', {
          'name': _name.text.trim().isEmpty ? 'Profile' : _name.text.trim(),
          'instructions': _instructions.text.trim(),
          'voiceId': _voice,
          'language': _language,
          'isDefault': _isDefault,
        });
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEdit) return;
    final token = AuthScope.of(context).token;
    if (token == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final id = widget.existing!['id']?.toString();
    try {
      await BackendApi(token).deleteJson('/api/profiles/$id');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit profile' : 'New profile'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _instructions,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          Text('Voice', style: t.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: kRealtimeVoices.contains(_voice) ? _voice : 'alloy',
            items: kRealtimeVoices
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => _voice = v ?? 'alloy'),
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 18),
          Text('Language (BCP-47)', style: t.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: kLanguageCodes.contains(_language) ? _language : 'en',
            items: kLanguageCodes
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => _language = v ?? 'en'),
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            title: const Text('Default profile'),
            value: _isDefault,
            onChanged: (v) => setState(() => _isDefault = v),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
