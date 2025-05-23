import 'package:flutter/foundation.dart';
import '../adapters/ai_adapter.dart';
import '../database/database_helper.dart';
import '../services/api_key_service.dart';
import '../services/github_service.dart';

/// Represents a single message in a conversation
class ConversationMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ConversationMessage({
    required this.text,    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Service that manages conversations using AI adapters with persistent storage
class ConversationService extends ChangeNotifier {
  AIAdapter? _currentAdapter;
  final List<ConversationMessage> _messages = [];
  bool _isProcessing = false;
  String? _error;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoaded = false;
  GitHubService? _githubService;

  AIAdapter? get currentAdapter => _currentAdapter;
  List<ConversationMessage> get messages => List.unmodifiable(_messages);
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  bool get isLoaded => _isLoaded;

  Future<void> loadConversationHistory() async {
    if (_isLoaded) return;
    try {
      final savedMessages = await _dbHelper.loadMessages();
      _messages.clear();
      _messages.addAll(savedMessages);
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load conversation history: $e';
      notifyListeners();
    }
  }

  Future<void> setAdapter(AIAdapter adapter) async {
    try {
      _error = null;
      await adapter.initialize();
      _currentAdapter = adapter;
      await _initializeGitHubService();
      if (!_isLoaded) {
        await loadConversationHistory();
      }
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize adapter: $e';
      notifyListeners();
    }
  }

  Future<void> _initializeGitHubService() async {
    try {
      final config = await ApiKeyService.getGitHubRepo();
      if (config['owner'] != null && config['repo'] != null) {
        _githubService = GitHubService(
          owner: config['owner']!,
          repo: config['repo']!,
          token: config['token'],
        );
      }
    } catch (e) {
      debugPrint('Failed to initialize GitHub service: $e');
    }
  }

  Future<void> sendMessage(String message) async {
    if (_currentAdapter == null) {
      _error = 'No AI adapter configured';
      notifyListeners();
      return;
    }

    if (message.trim().isEmpty) return;

    // Add user message
    final userMessage = ConversationMessage(text: message, isUser: true);
    _messages.add(userMessage);
    notifyListeners();

    try {
      await _dbHelper.insertMessage(userMessage, _currentAdapter!.name);
    } catch (e) {
      debugPrint('Failed to save user message: $e');
    }

    // Handle GitHub commands
    if (message.startsWith('/')) {
      await _handleGitHubCommand(message);
      return;
    }

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      // Build conversation history for AI
      final conversationHistory = _buildConversationHistory();

      // Send to AI
      final response = await _currentAdapter!.sendConversation(conversationHistory);

      // Add AI response
      final aiMessage = ConversationMessage(text: response, isUser: false);
      _messages.add(aiMessage);

      try {
        await _dbHelper.insertMessage(aiMessage, _currentAdapter!.name);
      } catch (e) {
        debugPrint('Failed to save AI message: $e');
      }

    } catch (e) {
      _error = 'Failed to get AI response: $e';
      final errorMessage = ConversationMessage(text: 'Error: $e', isUser: false);
      _messages.add(errorMessage);

      try {
        await _dbHelper.insertMessage(errorMessage, _currentAdapter?.name ?? 'Unknown');
      } catch (dbError) {
        debugPrint('Failed to save error message: $dbError');
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  List<ChatMessage> _buildConversationHistory() {
    // Get last 10 messages for context
    final recentMessages = _messages.length > 10
        ? _messages.skip(_messages.length - 10).toList()
        : _messages.toList();

    return recentMessages
        .where((msg) => !msg.text.startsWith('🤖 System:'))
        .map((msg) => ChatMessage(
      content: msg.text,
      isUser: msg.isUser,
      timestamp: msg.timestamp,
    ))
        .toList();
  }

  // [Keep all the existing GitHub methods exactly as they are]
  Future<void> _handleGitHubCommand(String command) async {
    if (_githubService == null) {
      _addSystemMessage('GitHub not configured. Use the menu to set up GitHub integration.');
      return;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final parts = command.split(' ');
      final cmd = parts[0].toLowerCase();

      switch (cmd) {
        case '/read':
          if (parts.length < 2) {
            _addSystemMessage('Usage: /read <filename>\nExample: /read lib/main.dart');
            break;
          }
          final filename = parts.sublist(1).join(' ');
          await _readFile(filename);
          break;
        case '/structure':
          await _showProjectStructure();
          break;
        case '/files':
          await _listFiles(parts.length > 1 ? parts[1] : null);
          break;
        case '/commits':
          await _showRecentCommits();
          break;
        case '/help':
          _showGitHubHelp();
          break;
        default:
          _addSystemMessage('Unknown command: $cmd\nType /help for available commands.');
      }
    } catch (e) {
      _addSystemMessage('GitHub command error: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void _addSystemMessage(String message) {
    final systemMessage = ConversationMessage(text: '🤖 System: $message', isUser: false);
    _messages.add(systemMessage);
    _dbHelper.insertMessage(systemMessage, 'System').catchError((e) {
      debugPrint('Failed to save system message: $e');
    });
  }

  Future<void> _readFile(String filename) async {
    try {
      final content = await _githubService!.readFile(filename);
      _addSystemMessage('📄 File: $filename\n\n```\n$content\n```');
    } catch (e) {
      _addSystemMessage('❌ Failed to read $filename: $e');
    }
  }

  Future<void> _showProjectStructure() async {
    try {
      final files = await _githubService!.getFileTree();
      final structure = _buildFileTree(files);
      _addSystemMessage('📁 Project Structure:\n\n$structure');
    } catch (e) {
      _addSystemMessage('❌ Failed to get project structure: $e');
    }
  }

  Future<void> _listFiles(String? path) async {
    try {
      final files = await _githubService!.getFileTree(path: path);
      final fileList = files.map((f) => '${f.isDirectory ? '📁' : '📄'} ${f.name}').join('\n');
      final pathStr = path ?? 'root';
      _addSystemMessage('📋 Files in $pathStr:\n\n$fileList');
    } catch (e) {
      _addSystemMessage('❌ Failed to list files: $e');
    }
  }

  Future<void> _showRecentCommits() async {
    try {
      final commits = await _githubService!.getRecentCommits(count: 5);
      final commitList = commits.map((c) =>
      '• ${c['commit']['message']}\n  by ${c['commit']['author']['name']} (${c['sha'].substring(0, 7)})'
      ).join('\n\n');
      _addSystemMessage('📝 Recent Commits:\n\n$commitList');
    } catch (e) {
      _addSystemMessage('❌ Failed to get recent commits: $e');
    }
  }

  void _showGitHubHelp() {
    _addSystemMessage('''
🔧 GitHub Commands:

/read <filename> - Read a file from the repository
/structure - Show the project file structure  
/files [path] - List files in a directory
/commits - Show recent commits
/help - Show this help message

Examples:
/read lib/main.dart
/read pubspec.yaml
/files lib
/structure
''');
  }

  String _buildFileTree(List<GitHubFile> files, [String prefix = '']) {
    final buffer = StringBuffer();
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final isLast = i == files.length - 1;
      final connector = isLast ? '└── ' : '├── ';
      final icon = file.isDirectory ? '📁' : '📄';
      buffer.writeln('$prefix$connector$icon ${file.name}');
    }
    return buffer.toString();
  }

  Future<void> clearConversation() async {
    try {
      await _dbHelper.clearMessages();
      _messages.clear();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear conversation: $e';
      notifyListeners();
    }
  }

  Future<int> getMessageCount() async {
    try {
      return await _dbHelper.getMessageCount();
    } catch (e) {
      debugPrint('Failed to get message count: $e');
      return 0;
    }
  }

  Future<void> cleanupOldMessages(int daysToKeep) async {
    try {
      await _dbHelper.deleteOldMessages(daysToKeep);
      _isLoaded = false;
      await loadConversationHistory();
    } catch (e) {
      _error = 'Failed to cleanup old messages: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _currentAdapter?.dispose();
    _dbHelper.close();
    super.dispose();
  }
}