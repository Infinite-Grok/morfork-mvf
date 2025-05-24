import 'dart:convert';
import 'package:http/http.dart' as http;

/// GitHub service for repository operations
/// Handles both read and write operations to GitHub repositories
class GitHubService {
  static GitHubService? _instance;
  String? _owner;
  String? _repo;
  String? _token;
  String get _baseUrl => 'https://api.github.com';

  GitHubService._();

  // Add constructor for backward compatibility
  factory GitHubService({String? owner, String? repo, String? token}) {
    final service = GitHubService.instance;
    if (owner != null && repo != null) {
      service.configure(owner: owner, repo: repo, token: token);
    }
    return service;
  }

  static GitHubService get instance {
    _instance ??= GitHubService._();
    return _instance!;
  }

  // Public getters for repository info
  String get owner => _owner ?? '';
  String get repo => _repo ?? '';
  bool get isConfigured => _owner != null && _repo != null;
  bool get canWrite => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers {
    final headers = {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'Morfork-MVF/1.0',
    };
    if (_token != null) {
      headers['Authorization'] = 'token $_token';
    }
    return headers;
  }

  /// Configure GitHub repository
  Future<bool> configure({
    required String owner,
    required String repo,
    String? token,
  }) async {
    _owner = owner;
    _repo = repo;
    _token = token;

    if (token != null && token.isNotEmpty) {
      return await testConnection();
    }
    return true;
  }

  /// Test GitHub connection
  Future<bool> testConnection() async {
    if (!isConfigured) return false;

    try {
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo');
      final response = await http.get(url, headers: _headers);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Test write permissions
  Future<bool> testWritePermissions() async {
    if (!canWrite || !isConfigured) return false;

    try {
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // If we can see private repo info, we likely have write access
        return data['private'] != null || data['permissions']?['push'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get repository structure
  Future<String> getRepositoryStructure() async {
    if (!isConfigured) return 'GitHub not configured';

    try {
      final structure = await _getDirectoryStructure('');
      return _formatStructure(structure);
    } catch (e) {
      return 'Error getting repository structure: $e';
    }
  }

  /// Get file content
  Future<String> getFileContent(String path) async {
    if (!isConfigured) return 'GitHub not configured';

    try {
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['content'] != null) {
          return utf8.decode(base64Decode(data['content'].replaceAll('\n', '')));
        }
      }
      return 'File not found or error reading file';
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  /// List files in directory
  Future<String> listFiles(String path) async {
    if (!isConfigured) return 'GitHub not configured';

    try {
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        final files = data.map((item) => item['name']).join('\n');
        return files;
      }
      return 'Directory not found';
    } catch (e) {
      return 'Error listing files: $e';
    }
  }

  /// Get recent commits
  Future<String> getRecentCommits({int count = 10}) async {
    if (!isConfigured) return 'GitHub not configured';

    try {
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/commits?per_page=$count');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final commits = jsonDecode(response.body) as List;
        return commits.map((commit) {
          final message = commit['commit']['message'];
          final author = commit['commit']['author']['name'];
          final date = commit['commit']['author']['date'];
          final sha = commit['sha'].substring(0, 7);
          return '$sha - $message ($author, $date)';
        }).join('\n');
      }
      return 'Error getting commits';
    } catch (e) {
      return 'Error getting commits: $e';
    }
  }

  /// Create or update file
  Future<Map<String, dynamic>> createOrUpdateFile({
    required String path,
    required String content,
    required String message,
    String? sha,
  }) async {
    if (!canWrite || !isConfigured) {
      return {'success': false, 'error': 'GitHub write not configured'};
    }

    try {
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');
      final body = {
        'message': message,
        'content': base64Encode(utf8.encode(content)),
      };

      if (sha != null) {
        body['sha'] = sha;
      }

      final response = await http.put(
        url,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'sha': data['content']['sha'],
          'url': data['content']['html_url'],
          'message': 'File ${sha != null ? 'updated' : 'created'} successfully',
        };
      } else {
        return {'success': false, 'error': 'GitHub API error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error creating/updating file: $e'};
    }
  }

  /// Delete file
  Future<Map<String, dynamic>> deleteFile({
    required String path,
    required String message,
    required String sha,
  }) async {
    if (!canWrite || !isConfigured) {
      return {'success': false, 'error': 'GitHub write not configured'};
    }

    try {
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');
      final body = {
        'message': message,
        'sha': sha,
      };

      final response = await http.delete(
        url,
        headers: {
          ..._headers,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'File deleted successfully'};
      } else {
        return {'success': false, 'error': 'GitHub API error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error deleting file: $e'};
    }
  }

  /// Get file SHA (needed for updates)
  Future<String?> getFileSha(String path) async {
    if (!isConfigured) return null;

    try {
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sha'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String path) async {
    if (!isConfigured) return false;

    try {
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');
      final response = await http.get(url, headers: _headers);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get GitHub status
  Map<String, dynamic> getStatus() {
    return {
      'configured': isConfigured,
      'repository': isConfigured ? '$_owner/$_repo' : 'Not configured',
      'writeToken': canWrite ? 'Configured' : 'Missing',
      'writePermissions': 'Unknown', // Will be checked async
    };
  }

  // Helper methods
  Future<List<Map<String, dynamic>>> _getDirectoryStructure(String path) async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$path');
    final response = await http.get(url, headers: _headers);

    if (response.statusCode != 200) return [];

    final items = jsonDecode(response.body) as List;
    final structure = <Map<String, dynamic>>[];

    for (final item in items) {
      final entry = {
        'name': item['name'],
        'type': item['type'],
        'path': item['path'],
      };

      if (item['type'] == 'dir') {
        entry['children'] = await _getDirectoryStructure(item['path']);
      }

      structure.add(entry);
    }

    return structure;
  }

  String _formatStructure(List<Map<String, dynamic>> structure, [String indent = '']) {
    final buffer = StringBuffer();

    for (final item in structure) {
      final name = item['name'];
      final type = item['type'];
      final icon = type == 'dir' ? '📁' : '📄';

      buffer.writeln('$indent$icon $name');

      if (type == 'dir' && item['children'] != null) {
        buffer.write(_formatStructure(item['children'], '$indent  '));
      }
    }

    return buffer.toString();
  }
}