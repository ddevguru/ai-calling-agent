import 'package:flutter/material.dart';

import 'auth_store.dart';
import 'telecom_service.dart';

class AuthScope extends InheritedWidget {
  const AuthScope({super.key, required this.auth, required super.child});

  final AuthStore auth;

  static AuthStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope missing');
    return scope!.auth;
  }

  @override
  bool updateShouldNotify(covariant AuthScope oldWidget) => oldWidget.auth != auth;
}

class TelecomScope extends InheritedWidget {
  const TelecomScope({super.key, required this.telecom, required super.child});

  final TelecomService telecom;

  static TelecomService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TelecomScope>();
    assert(scope != null, 'TelecomScope missing');
    return scope!.telecom;
  }

  @override
  bool updateShouldNotify(covariant TelecomScope oldWidget) =>
      oldWidget.telecom != telecom;
}
