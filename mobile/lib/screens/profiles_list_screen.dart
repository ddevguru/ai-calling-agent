import 'package:flutter/material.dart';

import '../api/backend_api.dart';
import '../app_scope.dart';
import 'profile_editor_screen.dart';

class ProfilesListScreen extends StatefulWidget {
  const ProfilesListScreen({super.key});

  @override
  State<ProfilesListScreen> createState() => _ProfilesListScreenState();
}

class _ProfilesListScreenState extends State<ProfilesListScreen> {
  var _loading = true;
  String? _error;
  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthScope.of(context).token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApi(token);
      final data = await api.getJson('/api/profiles');
      final list = (data['profiles'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _profiles = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI profiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProfileEditorScreen(),
            ),
          );
          await _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: _profiles.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final p = _profiles[i];
                      final def = p['is_default'] == true;
                      return Card(
                        child: ListTile(
                          title: Text(p['name']?.toString() ?? ''),
                          subtitle: Text(
                            '${p['voice_id'] ?? ''} · ${p['language'] ?? ''}',
                            style: t.bodySmall,
                          ),
                          trailing: def
                              ? const Chip(label: Text('Default'), visualDensity: VisualDensity.compact)
                              : null,
                          onTap: () async {
                            await Navigator.push<void>(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ProfileEditorScreen(existing: p),
                              ),
                            );
                            await _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
