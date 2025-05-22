import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing and retrieving API keys
class ApiKeyService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Storage keys
  static const String _grokApiKeyKey = 'grok_api_key';
  static const String _lastAdapterKey = 'last_adapter_type';

  /// Save Grok API key securely
  static Future<void> saveGrokApiKey(String apiKey) async {
    await _storage.write(key: _grokApiKeyKey, value: apiKey);
  }

  /// Retrieve saved Grok API key
  static Future<String?> getGrokApiKey() async {
    return await _storage.read(key: _grokApiKeyKey);
  }

  /// Remove Grok API key
  static Future<void> removeGrokApiKey() async {
    await _storage.delete(key: _grokApiKeyKey);
  }

  /// Save the type of adapter that was last used
  static Future<void> saveLastAdapter(String adapterType) async {
    await _storage.write(key: _lastAdapterKey, value: adapterType);
  }

  /// Get the type of adapter that was last used
  static Future<String?> getLastAdapter() async {
    return await _storage.read(key: _lastAdapterKey);
  }

  /// Check if Grok API key exists
  static Future<bool> hasGrokApiKey() async {
    final key = await getGrokApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Clear all stored API keys and preferences
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}