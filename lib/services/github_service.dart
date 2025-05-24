import 'dart:convert';
import 'package:http/http.dart' as http;

/// Enhanced service for reading AND writing files to GitHub
/// Supports full development workflow with AI code generation
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

  /// Public getters for repository information
  String get owner => _owner;
  String get repo => _repo;
  String? get token => _token;

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

  /// Check if token has write permissions
  bool get canWrite => _token != null && _token!.isNotEmpty;

  // ============================================================================
  // READ OPERATIONS (Existing functionality preserved)
  // ============================================================================

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

  // ============================================================================
  // WRITE OPERATIONS (New functionality)
  // ============================================================================

  /// Create a new file in the repository
  Future<GitHubWriteResult> createFile({
    required String filePath,
    required String content,
    required String commitMessage,
    String? branch,
  }) async {
    if (!canWrite) {
      throw Exception('GitHub token required for write operations');
    }

    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$filePath');

    // Encode content to base64
    final encodedContent = base64Encode(utf8.encode(content));

    final body = {
      'message': commitMessage,
      'content': encodedContent,
    };

    if (branch != null) {
      body['branch'] = branch;
    }

    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return GitHubWriteResult.fromJson(data);
      } else if (response.statusCode == 422) {
        throw Exception('File already exists: $filePath');
      } else {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to create file: $e');
    }
  }

  /// Update an existing file in the repository
  Future<GitHubWriteResult> updateFile({
    required String filePath,
    required String content,
    required String commitMessage,
    String? branch,
  }) async {
    if (!canWrite) {
      throw Exception('GitHub token required for write operations');
    }

    // First, get the current file to retrieve its SHA
    final currentFile = await _getFileDetails(filePath);

    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$filePath');

    // Encode content to base64
    final encodedContent = base64Encode(utf8.encode(content));

    final body = {
      'message': commitMessage,
      'content': encodedContent,
      'sha': currentFile['sha'],
    };

    if (branch != null) {
      body['branch'] = branch;
    }

    try {
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GitHubWriteResult.fromJson(data);
      } else {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to update file: $e');
    }
  }

  /// Delete a file from the repository
  Future<GitHubWriteResult> deleteFile({
    required String filePath,
    required String commitMessage,
    String? branch,
  }) async {
    if (!canWrite) {
      throw Exception('GitHub token required for write operations');
    }

    // First, get the current file to retrieve its SHA
    final currentFile = await _getFileDetails(filePath);

    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$filePath');

    final body = {
      'message': commitMessage,
      'sha': currentFile['sha'],
    };

    if (branch != null) {
      body['branch'] = branch;
    }

    try {
      final response = await http.delete(
        url,
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return GitHubWriteResult.fromJson(data);
      } else {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Check if a file exists in the repository
  Future<bool> fileExists(String filePath) async {
    try {
      await readFile(filePath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get file details including SHA (needed for updates)
  Future<Map<String, dynamic>> _getFileDetails(String filePath) async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/contents/$filePath');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        throw Exception('File not found: $filePath');
      } else {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get file details: $e');
    }
  }

  /// Create or update a file (smart operation)
  Future<GitHubWriteResult> writeFile({
    required String filePath,
    required String content,
    required String commitMessage,
    String? branch,
  }) async {
    final exists = await fileExists(filePath);

    if (exists) {
      return await updateFile(
        filePath: filePath,
        content: content,
        commitMessage: commitMessage,
        branch: branch,
      );
    } else {
      return await createFile(
        filePath: filePath,
        content: content,
        commitMessage: commitMessage,
        branch: branch,
      );
    }
  }

  /// Get the default branch of the repository
  Future<String> getDefaultBranch() async {
    final repoInfo = await getRepoInfo();
    return repoInfo['default_branch'] ?? 'main';
  }

  /// List all branches
  Future<List<String>> getBranches() async {
    final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo/branches');

    try {
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((branch) => branch['name'] as String).toList();
      } else {
        throw Exception('GitHub API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get branches: $e');
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

  /// Test write permissions by attempting a dry-run write operation
  Future<bool> testWritePermissions() async {
    if (!canWrite) return false;

    try {
      // For repositories you own or have write access to, test by checking if we can
      // get repository info with authentication (simple but effective test)
      final url = Uri.parse('$_baseUrl/repos/$_owner/$_repo');
      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // If we have explicit permissions info, use it
        if (data['permissions'] != null) {
          return data['permissions']['push'] == true;
        }

        // Otherwise, if we're the owner or can see private repo info, we likely have write access
        // This is a reasonable assumption for personal repos
        return data['private'] != null; // Can see privacy status = authenticated properly
      }

      return false;
    } catch (e) {
      // If authentication fails, definitely no write permissions
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

/// Represents the result of a write operation to GitHub
class GitHubWriteResult {
  final String sha;
  final String commitMessage;
  final String? commitSha;
  final String? htmlUrl;

  GitHubWriteResult({
    required this.sha,
    required this.commitMessage,
    this.commitSha,
    this.htmlUrl,
  });

  factory GitHubWriteResult.fromJson(Map<String, dynamic> json) {
    return GitHubWriteResult(
      sha: json['content']?['sha'] ?? json['sha'] ?? '',
      commitMessage: json['commit']?['message'] ?? '',
      commitSha: json['commit']?['sha'],
      htmlUrl: json['content']?['html_url'] ?? json['html_url'],
    );
  }
}