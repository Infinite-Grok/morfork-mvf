import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html show window;

/// Service for securely storing and retrieving API keys and settings
/// Uses localStorage for web, secure storage for mobile
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

  /// Write a value to storage (web-compatible)
  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      html.window.localStorage[key] = value;
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  /// Read a value from storage (web-compatible)
  static Future<String?> _read(String key) async {
    if (kIsWeb) {
      return html.window.localStorage[key];
    } else {
      return await _storage.read(key: key);
    }
  }

  /// Delete a value from storage (web-compatible)
  static Future<void> _delete(String key) async {
    if (kIsWeb) {
      html.window.localStorage.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  /// Clear all storage (web-compatible)
  static Future<void> _deleteAll() async {
    if (kIsWeb) {
      // Clear only our keys to avoid affecting other apps
      final keys = [
        _grokApiKeyKey,
        _claudeApiKeyKey,
        _lastAdapterKey,
        _githubOwnerKey,
        _githubRepoKey,
        _githubTokenKey,
      ];
      for (final key in keys) {
        html.window.localStorage.remove(key);
      }
    } else {
      await _storage.deleteAll();
    }
  }

  // === GROK API KEY MANAGEMENT ===

  /// Save Grok API key securely
  static Future<void> saveGrokApiKey(String apiKey) async {
    await _write(_grokApiKeyKey, apiKey);
  }

  /// Retrieve saved Grok API key
  static Future<String?> getGrokApiKey() async {
    return await _read(_grokApiKeyKey);
  }

  /// Remove Grok API key
  static Future<void> removeGrokApiKey() async {
    await _delete(_grokApiKeyKey);
  }

  /// Check if Grok API key exists
  static Future<bool> hasGrokApiKey() async {
    final key = await getGrokApiKey();
    return key != null && key.isNotEmpty;
  }

  // === CLAUDE API KEY MANAGEMENT ===

  /// Save Claude API key securely
  static Future<void> saveClaudeApiKey(String apiKey) async {
    await _write(_claudeApiKeyKey, apiKey);
  }

  /// Retrieve saved Claude API key
  static Future<String?> getClaudeApiKey() async {
    return await _read(_claudeApiKeyKey);
  }

  /// Remove Claude API key
  static Future<void> removeClaudeApiKey() async {
    await _delete(_claudeApiKeyKey);
  }

  /// Check if Claude API key exists
  static Future<bool> hasClaudeApiKey() async {
    final key = await getClaudeApiKey();
    return key != null && key.isNotEmpty;
  }

  // === ADAPTER MANAGEMENT ===

  /// Save the type of adapter that was last used
  static Future<void> saveLastAdapter(String adapterType) async {
    await _write(_lastAdapterKey, adapterType);
  }

  /// Get the type of adapter that was last used
  static Future<String?> getLastAdapter() async {
    return await _read(_lastAdapterKey);
  }

  // === GITHUB INTEGRATION SETTINGS ===

  /// Save GitHub repository information
  static Future<void> saveGitHubRepo({
    required String owner,
    required String repo,
    String? token,
  }) async {
    await _write(_githubOwnerKey, owner);
    await _write(_githubRepoKey, repo);
    if (token != null && token.isNotEmpty) {
      await _write(_githubTokenKey, token);
    }

    // DEBUG: Print what we just saved (for web debugging)
    if (kIsWeb) {
      print('🔧 GitHub Config Saved:');
      print('  Owner: $owner');
      print('  Repo: $repo');
      print('  Token: ${token?.isNotEmpty == true ? "***${token!.substring(token.length - 4)}" : "null"}');
    }
  }

  /// Get GitHub repository information
  static Future<Map<String, String?>> getGitHubRepo() async {
    final result = {
      'owner': await _read(_githubOwnerKey),
      'repo': await _read(_githubRepoKey),
      'token': await _read(_githubTokenKey),
    };

    // DEBUG: Print what we retrieved (for web debugging)
    if (kIsWeb) {
      print('🔍 GitHub Config Retrieved:');
      print('  Owner: ${result['owner'] ?? "null"}');
      print('  Repo: ${result['repo'] ?? "null"}');
      print('  Token: ${result['token']?.isNotEmpty == true ? "***${result['token']!.substring(result['token']!.length - 4)}" : "null"}');
    }

    return result;
  }

  /// Check if GitHub repository is configured
  static Future<bool> hasGitHubRepo() async {
    final repo = await getGitHubRepo();
    final hasConfig = repo['owner'] != null &&
        repo['repo'] != null &&
        repo['owner']!.isNotEmpty &&
        repo['repo']!.isNotEmpty;

    if (kIsWeb) {
      print('🔍 GitHub Config Check: $hasConfig');
    }

    return hasConfig;
  }

  /// Remove GitHub repository settings
  static Future<void> removeGitHubRepo() async {
    await _delete(_githubOwnerKey);
    await _delete(_githubRepoKey);
    await _delete(_githubTokenKey);
  }

  // === UTILITY METHODS ===

  /// Clear all stored API keys and preferences
  static Future<void> clearAll() async {
    await _deleteAll();
  }

  /// Get summary of configured services
  static Future<Map<String, bool>> getConfigurationStatus() async {
    return {
      'grok': await hasGrokApiKey(),
      'claude': await hasClaudeApiKey(),
      'github': await hasGitHubRepo(),
    };
  }

  /// DEBUG: Print all stored values (for debugging only)
  static Future<void> debugPrintAll() async {
    if (kIsWeb) {
      print('🔍 ALL STORED VALUES:');
      print('  Grok: ${await _read(_grokApiKeyKey) ?? "null"}');
      print('  Claude: ${await _read(_claudeApiKeyKey) ?? "null"}');
      print('  GitHub Owner: ${await _read(_githubOwnerKey) ?? "null"}');
      print('  GitHub Repo: ${await _read(_githubRepoKey) ?? "null"}');
      print('  GitHub Token: ${(await _read(_githubTokenKey))?.isNotEmpty == true ? "SET" : "null"}');
      print('  Last Adapter: ${await _read(_lastAdapterKey) ?? "null"}');
    }
  }
}