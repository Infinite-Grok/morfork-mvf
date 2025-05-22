import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing and retrieving API keys and settings
class ApiKeyService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Storage keys
  static const String _grokApiKeyKey = 'grok_api_key';
  static const String _claudeApiKeyKey = 'claude_api_key';
  static const String _lastAdapterKey = 'last_adapter_type';
  static const String _githubOwnerKey = 'github_owner';
  static const String _githubRepoKey = 'github_repo';
  static const String _githubTokenKey = 'github_token';

  // === GROK API KEY MANAGEMENT ===

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

  /// Check if Grok API key exists
  static Future<bool> hasGrokApiKey() async {
    final key = await getGrokApiKey();
    return key != null && key.isNotEmpty;
  }

  // === CLAUDE API KEY MANAGEMENT ===

  /// Save Claude API key securely
  static Future<void> saveClaudeApiKey(String apiKey) async {
    await _storage.write(key: _claudeApiKeyKey, value: apiKey);
  }

  /// Retrieve saved Claude API key
  static Future<String?> getClaudeApiKey() async {
    return await _storage.read(key: _claudeApiKeyKey);
  }

  /// Remove Claude API key
  static Future<void> removeClaudeApiKey() async {
    await _storage.delete(key: _claudeApiKeyKey);
  }

  /// Check if Claude API key exists
  static Future<bool> hasClaudeApiKey() async {
    final key = await getClaudeApiKey();
    return key != null && key.isNotEmpty;
  }

  // === ADAPTER MANAGEMENT ===

  /// Save the type of adapter that was last used
  static Future<void> saveLastAdapter(String adapterType) async {
    await _storage.write(key: _lastAdapterKey, value: adapterType);
  }

  /// Get the type of adapter that was last used
  static Future<String?> getLastAdapter() async {
    return await _storage.read(key: _lastAdapterKey);
  }

  // === GITHUB INTEGRATION SETTINGS ===

  /// Save GitHub repository information
  static Future<void> saveGitHubRepo({
    required String owner,
    required String repo,
    String? token,
  }) async {
    await _storage.write(key: _githubOwnerKey, value: owner);
    await _storage.write(key: _githubRepoKey, value: repo);
    if (token != null) {
      await _storage.write(key: _githubTokenKey, value: token);
    }
  }

  /// Get GitHub repository information
  static Future<Map<String, String?>> getGitHubRepo() async {
    return {
      'owner': await _storage.read(key: _githubOwnerKey),
      'repo': await _storage.read(key: _githubRepoKey),
      'token': await _storage.read(key: _githubTokenKey),
    };
  }

  /// Check if GitHub repository is configured
  static Future<bool> hasGitHubRepo() async {
    final repo = await getGitHubRepo();
    return repo['owner'] != null && repo['repo'] != null;
  }

  /// Remove GitHub repository settings
  static Future<void> removeGitHubRepo() async {
    await _storage.delete(key: _githubOwnerKey);
    await _storage.delete(key: _githubRepoKey);
    await _storage.delete(key: _githubTokenKey);
  }

  // === UTILITY METHODS ===

  /// Clear all stored API keys and preferences
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Get summary of configured services
  static Future<Map<String, bool>> getConfigurationStatus() async {
    return {
      'grok': await hasGrokApiKey(),
      'claude': await hasClaudeApiKey(),
      'github': await hasGitHubRepo(),
    };
  }
}