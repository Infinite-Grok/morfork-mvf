import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for reading files and project information from GitHub
class GitHubService {
  final String _owner;
  final String _repo;
  final String? _token;
  final String _baseUrl = 'https://api.github.com';

  GitHubService({
    required String owner,
    required String repo,
    String? token,
  }) : _owner = owner, _repo = repo, _token = token;

  /// Get headers for GitHub API requests
  Map<String, String> get _headers {
    final headers = {
      'Accept': 'application/vnd.github.v3+json',
      'User-Agent': 'Morfork-App',
    };

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'token $_token';
    }

    return headers;
  }

  /// Read a file from the repository
  Future<String> readFile(String filePath) async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$filePath');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // GitHub returns base64 encoded content
        if (data['content'] != null) {
          final base64Content = data['content'].replaceAll('\n', '');
          final decodedBytes = base64Decode(base64Content);
          return utf8.decode(decodedBytes);
        } else {
          throw Exception('No content found in file');
        }
      } else if (response.statusCode == 404) {
        throw Exception('File not found: $filePath');
      } else {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to read file from GitHub: $e');
    }
  }

  /// Get repository file tree
  Future<List<GitHubFile>> getFileTree({String? path}) async {
    final treePath = path ?? '';
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$treePath');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        return data.map((item) => GitHubFile.fromJson(item)).toList();
      } else {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get file tree: $e');
    }
  }

  /// Get repository information
  Future<Map<String, dynamic>> getRepoInfo() async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get repository info: $e');
    }
  }

  /// Get recent commits
  Future<List<Map<String, dynamic>>> getRecentCommits({int count = 10}) async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/commits?per_page=$count');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get recent commits: $e');
    }
  }

  /// Check if repository is accessible
  Future<bool> testConnection() async {
    try {
      await getRepoInfo();
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Represents a file or directory in GitHub
class GitHubFile {
  final String name;
  final String path;
  final String type; // 'file' or 'dir'
  final int size;
  final String downloadUrl;

  GitHubFile({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
    required this.downloadUrl,
  });

  factory GitHubFile.fromJson(Map<String, dynamic> json) {
    return GitHubFile(
      name: json['name'] ?? '',
      path: json['path'] ?? '',
      type: json['type'] ?? 'file',
      size: json['size'] ?? 0,
      downloadUrl: json['download_url'] ?? '',
    );
  }

  bool get isFile => type == 'file';
  bool get isDirectory => type == 'dir';
}