import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _androidSecureOptions = AndroidOptions(encryptedSharedPreferences: true);

/// One-time migration: move value from SharedPreferences to FlutterSecureStorage.
Future<void> _migrateToSecureStorage(
  FlutterSecureStorage secure,
  SharedPreferences prefs,
  String key,
) async {
  final existing = await secure.read(key: key);
  if (existing != null && existing.isNotEmpty) return;
  final legacy = prefs.getString(key);
  if (legacy != null && legacy.isNotEmpty) {
    await secure.write(key: key, value: legacy);
    await prefs.remove(key);
  }
}

/// Notifier for a single string preference stored in secure storage.
/// On mobile (Android/iOS) uses [FlutterSecureStorage]; on other platforms uses [SharedPreferences].
/// Migrates from SharedPreferences to secure storage once on first read.
class SecureStringNotifier extends StateNotifier<String> {
  SecureStringNotifier({
    required this.storageKey,
    required this.defaultValue,
    required Ref ref,
  })  : _ref = ref,
        super(defaultValue) {
    _init();
  }

  final String storageKey;
  final String defaultValue;
  final Ref _ref;

  Future<void> _init() async {
    if (Platform.isLinux || Platform.isWindows) {
      final prefs = _ref.read(sharedPreferencesProvider).requireValue;
      state = prefs.getString(storageKey) ?? defaultValue;
      return;
    }
    const secure = FlutterSecureStorage(aOptions: _androidSecureOptions);
    final prefs = _ref.read(sharedPreferencesProvider).requireValue;
    await _migrateToSecureStorage(secure, prefs, storageKey);
    final value = await secure.read(key: storageKey);
    state = value ?? defaultValue;
  }

  /// For compatibility with import flow that calls updateRaw.
  Future<void> updateRaw(dynamic value) async => update(value as String);

  Future<void> update(String value) async {
    if (Platform.isLinux || Platform.isWindows) {
      final prefs = _ref.read(sharedPreferencesProvider).requireValue;
      await prefs.setString(storageKey, value);
      state = value;
      return;
    }
    const secure = FlutterSecureStorage(aOptions: _androidSecureOptions);
    await secure.write(key: storageKey, value: value);
    state = value;
  }

  Future<void> reset() async {
    if (Platform.isLinux || Platform.isWindows) {
      final prefs = _ref.read(sharedPreferencesProvider).requireValue;
      await prefs.remove(storageKey);
    } else {
      const secure = FlutterSecureStorage(aOptions: _androidSecureOptions);
      await secure.delete(key: storageKey);
    }
    state = defaultValue;
    _ref.invalidateSelf();
  }
}

/// Provider for [FlutterSecureStorage] (mobile only).
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(aOptions: _androidSecureOptions);
});

/// Creates a [StateNotifierProvider] for a string preference in secure storage.
StateNotifierProvider<SecureStringNotifier, String> secureStringProvider(
  String key,
  String defaultValue,
) {
  return StateNotifierProvider<SecureStringNotifier, String>((ref) {
    return SecureStringNotifier(
      storageKey: key,
      defaultValue: defaultValue,
      ref: ref,
    );
  });
}
