import 'dart:async';
import 'package:flutter/foundation.dart';
import '../adapters/ai_adapter.dart';
import '../database/database_helper.dart';
import 'github_service.dart';

class ConversationMessage {
  final int? id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? metadata;

  ConversationMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser ? 1 : 0,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'metadata': metadata,
    };
  }

  factory ConversationMessage.fromMap(Map<String, dynamic> map) {
    return ConversationMessage(
      id: map['id'],
      text: map['text'],
      isUser: map['isUser'] == 1,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      metadata: map['metadata'],
    );
  }
}

class ConversationService with ChangeNotifier {
  static final ConversationService _instance = ConversationService._internal();
  factory ConversationService() => _instance;
  ConversationService._internal();

  AIAdapter? _currentAdapter;
  final List<ConversationMessage> _messages = [];
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final GitHubService _githubService = GitHubService.instance;
  bool _isLoading = false;
  bool _projectContextLoaded = false;
  final Set<String> _loadedFiles = {};

  // Getters
  List<ConversationMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get currentAdapterName => _currentAdapter?.name ?? 'No adapter selected';
  bool get hasAdapter => _currentAdapter != null;
  AIAdapter? get currentAdapter => _currentAdapter;
  bool get isProcessing => _isLoading;
  bool get isLoaded => true;
  String? get error => null;

  // Initialize service with auto-context loading
  Future<void> initialize() async {
    await _databaseHelper.database;
    await _loadConversationHistory();

    // Auto-load project context if GitHub is configured
    if (_githubService.isConfigured && !_projectContextLoaded) {
      await _loadProjectContext();
    }
  }

  // Auto-load project context
  Future<void> _loadProjectContext() async {
    try {
      _projectContextLoaded = true;

      // Load project structure
      final structure = await _githubService.getRepositoryStructure();
      final contextMessage = ConversationMessage(
        text: '🎯 Auto-loaded project context:\n\n📁 Project Structure:\n$structure',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(contextMessage);

      // Load key files automatically
      final keyFiles = ['lib/main.dart', 'pubspec.yaml', 'README.md'];
      for (final file in keyFiles) {
        if (await _githubService.fileExists(file)) {
          final content = await _githubService.getFileContent(file);
          final fileMessage = ConversationMessage(
            text: '📄 Auto-loaded $file:\n\n```\n$content\n```',
            isUser: false,
            timestamp: DateTime.now(),
          );
          _addMessage(fileMessage);
          _loadedFiles.add(file);
        }
      }

      // Add AI awareness message
      final awarenessMessage = ConversationMessage(
        text: '🧠 I now have full awareness of your ${_githubService.repo} project structure and key files. I can discuss your code, suggest improvements, help with debugging, or help you build new features. What would you like to work on?',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(awarenessMessage);

    } catch (e) {
      final errorMessage = ConversationMessage(
        text: '⚠️ Could not auto-load project context: $e',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(errorMessage);
    }
  }

  // Set AI adapter
  Future<void> setAdapter(AIAdapter adapter) async {
    _currentAdapter = adapter;
    await adapter.initialize();

    // Add connection message
    final connectionMessage = ConversationMessage(
      text: '🔗 Connected to ${adapter.name}',
      isUser: false,
      timestamp: DateTime.now(),
    );

    _addMessage(connectionMessage);

    // If project context is loaded, remind AI of it
    if (_projectContextLoaded) {
      final reminderMessage = ConversationMessage(
        text: '🧠 AI context restored: I have full awareness of your ${_githubService.repo} project including structure and ${_loadedFiles.length} key files.',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(reminderMessage);
    }

    notifyListeners();
  }

  // Reinitialize GitHub
  Future<void> reinitializeGitHub() async {
    _projectContextLoaded = false;
    _loadedFiles.clear();
    if (_githubService.isConfigured) {
      await _loadProjectContext();
    }
  }

  // Enhanced send message with auto file loading
  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final userMessage = ConversationMessage(
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _addMessage(userMessage);

    try {
      _setLoading(true);

      // Check if message mentions files that aren't loaded yet
      await _checkAndLoadMentionedFiles(message);

      // Handle GitHub commands
      if (message.startsWith('/')) {
        final result = await _handleGitHubCommand(message);
        final systemMessage = ConversationMessage(
          text: result,
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(systemMessage);
      } else {
        // Handle AI conversation with enhanced context
        if (_currentAdapter == null) {
          final errorMessage = ConversationMessage(
            text: '❌ No AI adapter selected. Please select an adapter first.',
            isUser: false,
            timestamp: DateTime.now(),
          );
          _addMessage(errorMessage);
        } else {
          final conversationHistory = _buildEnhancedConversationHistory();
          final response = await _currentAdapter!.sendConversation(conversationHistory);

          final aiMessage = ConversationMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          );
          _addMessage(aiMessage);

          // Check if AI response contains code for pending file operations
          await _processAIResponseForFileOps(response);

          // Check if AI response suggests loading more files
          await _checkForAISuggestedFiles(response);
        }
      }
    } catch (e) {
      final errorMessage = ConversationMessage(
        text: '❌ Error: $e',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Auto-detect and load mentioned files
  Future<void> _checkAndLoadMentionedFiles(String message) async {
    final filePatterns = [
      RegExp(r'lib/[\w/]+\.dart'),
      RegExp(r'[\w/]+\.yaml'),
      RegExp(r'[\w/]+\.json'),
      RegExp(r'[\w/]+\.md'),
      RegExp(r'test/[\w/]+\.dart'),
    ];

    for (final pattern in filePatterns) {
      final matches = pattern.allMatches(message);
      for (final match in matches) {
        final filename = match.group(0)!;
        if (!_loadedFiles.contains(filename)) {
          await _autoLoadFile(filename);
        }
      }
    }
  }

  // Auto-load a specific file
  Future<void> _autoLoadFile(String filename) async {
    try {
      if (await _githubService.fileExists(filename)) {
        final content = await _githubService.getFileContent(filename);
        final fileMessage = ConversationMessage(
          text: '🔄 Auto-loaded $filename for context:\n\n```\n$content\n```',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(fileMessage);
        _loadedFiles.add(filename);
      }
    } catch (e) {
      // Silently fail - don't spam user with file load errors
    }
  }

  // GitHub Write Operations
  String? _pendingFileOperation;
  String? _pendingFileName;
  String? _pendingFileContent;

  // Start file creation workflow
  Future<String> _startFileCreation(String filename) async {
    if (!await _githubService.testWritePermissions()) {
      return '❌ GitHub write permissions not available. Please configure your GitHub token with write access.';
    }

    if (await _githubService.fileExists(filename)) {
      return '⚠️ File $filename already exists. Use /edit to modify it or choose a different filename.';
    }

    _pendingFileOperation = 'create';
    _pendingFileName = filename;

    return '''
📝 Ready to create: $filename

I'll help you create this file. Please describe what you want in the file, and I'll generate the appropriate content and create it in your GitHub repository.

What should this file contain?
''';
  }

  // Start file edit workflow
  Future<String> _startFileEdit(String filename) async {
    if (!await _githubService.testWritePermissions()) {
      return '❌ GitHub write permissions not available. Please configure your GitHub token with write access.';
    }

    if (!await _githubService.fileExists(filename)) {
      return '❌ File $filename does not exist. Use /create to create a new file.';
    }

    // Load current content
    final currentContent = await _githubService.getFileContent(filename);

    _pendingFileOperation = 'edit';
    _pendingFileName = filename;
    _pendingFileContent = currentContent;

    // Auto-load the file for context if not already loaded
    if (!_loadedFiles.contains(filename)) {
      await _autoLoadFile(filename);
    }

    return '''
✏️ Ready to edit: $filename

Current file content is now loaded in our conversation context. Please describe the changes you want to make, and I'll modify the file accordingly.

What changes would you like to make to this file?
''';
  }

  // Delete file
  Future<String> _deleteFile(String filename) async {
    if (!await _githubService.testWritePermissions()) {
      return '❌ GitHub write permissions not available. Please configure your GitHub token with write access.';
    }

    if (!await _githubService.fileExists(filename)) {
      return '❌ File $filename does not exist.';
    }

    try {
      // Get file SHA for deletion
      final sha = await _githubService.getFileSha(filename);
      if (sha == null) {
        return '❌ Could not get file information for deletion.';
      }

      // Delete the file
      final result = await _githubService.deleteFile(
        path: filename,
        message: 'Delete $filename via Morfork AI',
        sha: sha,
      );

      if (result['success'] == true) {
        // Remove from loaded files
        _loadedFiles.remove(filename);

        return '''
✅ Successfully deleted: $filename

The file has been removed from your GitHub repository.
''';
      } else {
        return '❌ Failed to delete file: ${result['error']}';
      }
    } catch (e) {
      return '❌ Error deleting file: $e';
    }
  }

  // Process AI response for file operations
  Future<void> _processAIResponseForFileOps(String aiResponse) async {
    if (_pendingFileOperation == null || _pendingFileName == null) return;

    // Check if AI provided code in the response
    final codeBlocks = _extractCodeBlocks(aiResponse);

    if (codeBlocks.isNotEmpty) {
      // Use the first code block as file content
      final fileContent = codeBlocks.first;

      try {
        String? result;

        if (_pendingFileOperation == 'create') {
          result = await _createFileOnGitHub(_pendingFileName!, fileContent);
        } else if (_pendingFileOperation == 'edit') {
          result = await _updateFileOnGitHub(_pendingFileName!, fileContent);
        }

        if (result != null) {
          // Add system message about the file operation
          final systemMessage = ConversationMessage(
            text: result,
            isUser: false,
            timestamp: DateTime.now(),
          );
          _addMessage(systemMessage);

          // Clear pending operation
          _pendingFileOperation = null;
          _pendingFileName = null;
          _pendingFileContent = null;
        }
      } catch (e) {
        final errorMessage = ConversationMessage(
          text: '❌ Error executing file operation: $e',
          isUser: false,
          timestamp: DateTime.now(),
        );
        _addMessage(errorMessage);
      }
    }
  }

  // Extract code blocks from AI response
  List<String> _extractCodeBlocks(String text) {
    final codeBlockRegex = RegExp(r'```(?:\w+\n)?(.*?)```', dotAll: true);
    return codeBlockRegex.allMatches(text)
        .map((match) => match.group(1)?.trim() ?? '')
        .where((code) => code.isNotEmpty)
        .toList();
  }

  // Create file on GitHub
  Future<String> _createFileOnGitHub(String filename, String content) async {
    final result = await _githubService.createOrUpdateFile(
      path: filename,
      content: content,
      message: 'Create $filename via Morfork AI',
    );

    if (result['success'] == true) {
      // Add to loaded files
      _loadedFiles.add(filename);

      return '''
✅ Successfully created: $filename

🔗 Repository: ${_githubService.owner}/${_githubService.repo}
📄 View file: ${result['url']}
📝 Commit: ${result['sha']?.substring(0, 7)}

The file has been created in your GitHub repository!
''';
    } else {
      return '❌ Failed to create file: ${result['error']}';
    }
  }

  // Update file on GitHub
  Future<String> _updateFileOnGitHub(String filename, String content) async {
    // Get current file SHA for update
    final sha = await _githubService.getFileSha(filename);
    if (sha == null) {
      return '❌ Could not get current file information for update.';
    }

    final result = await _githubService.createOrUpdateFile(
      path: filename,
      content: content,
      message: 'Update $filename via Morfork AI',
      sha: sha,
    );

    if (result['success'] == true) {
      return '''
✅ Successfully updated: $filename

🔗 Repository: ${_githubService.owner}/${_githubService.repo}
📄 View file: ${result['url']}
📝 Commit: ${result['sha']?.substring(0, 7)}

The file has been updated in your GitHub repository!
''';
    } else {
      return '❌ Failed to update file: ${result['error']}';
    }
  }
  Future<void> _checkForAISuggestedFiles(String aiResponse) async {
    // If AI mentions files it can't see, offer to load them
    if (aiResponse.contains('would need to see') ||
        aiResponse.contains('could you show me') ||
        aiResponse.contains('without seeing the')) {

      final suggestionMessage = ConversationMessage(
        text: '💡 I noticed I might need more file context. Try mentioning specific filenames (like "lib/services/api_service.dart") and I\'ll automatically load them for you!',
        isUser: false,
        timestamp: DateTime.now(),
      );
      _addMessage(suggestionMessage);
    }
  }

  // Handle GitHub commands (enhanced)
  Future<String> _handleGitHubCommand(String command) async {
    final parts = command.split(' ');
    final cmd = parts[0].toLowerCase();

    try {
      switch (cmd) {
        case '/help':
          return '''
🔧 GitHub Commands:
• /structure - Show repository structure
• /read <filename> - Read file content
• /files [path] - List files in directory
• /commits - Show recent commits
• /status - GitHub connection status
• /context - Reload project context
• /loaded - Show loaded files

🚀 GitHub Write Commands:
• /create <filename> - Create new file with AI
• /edit <filename> - Edit existing file with AI
• /delete <filename> - Delete file from repository
''';

        case '/create':
          if (parts.length < 2) return '❌ Usage: /create <filename>';
          final filename = parts.sublist(1).join(' ');
          return await _startFileCreation(filename);

        case '/edit':
          if (parts.length < 2) return '❌ Usage: /edit <filename>';
          final filename = parts.sublist(1).join(' ');
          return await _startFileEdit(filename);

        case '/delete':
          if (parts.length < 2) return '❌ Usage: /delete <filename>';
          final filename = parts.sublist(1).join(' ');
          return await _deleteFile(filename);

        case '/context':
          await _loadProjectContext();
          return '🔄 Project context reloaded!';

        case '/loaded':
          return '📚 Loaded files (${_loadedFiles.length}):\n${_loadedFiles.join('\n')}';

        case '/structure':
          final structure = await _githubService.getRepositoryStructure();
          return '📁 Repository Structure:\n$structure';

        case '/read':
          if (parts.length < 2) return '❌ Usage: /read <filename>';
          final filename = parts.sublist(1).join(' ');
          await _autoLoadFile(filename);
          return '✅ Loaded $filename into conversation context';

        case '/files':
          final path = parts.length > 1 ? parts.sublist(1).join(' ') : '';
          final files = await _githubService.listFiles(path);
          return '📂 Files in ${path.isEmpty ? 'root' : path}:\n$files';

        case '/commits':
          final commits = await _githubService.getRecentCommits();
          return '📝 Recent commits:\n$commits';

        case '/status':
          final status = _githubService.getStatus();
          final writePermissions = await _githubService.testWritePermissions();

          return '''
📊 GitHub Status:

Repository: ${status['repository']}
Write Token: ${status['writeToken'] == 'Configured' ? '✅ Configured' : '❌ Missing'}
Write Permissions: ${writePermissions ? '✅ Verified' : '❌ No push access'}
Project Context: ${_projectContextLoaded ? '✅ Loaded' : '❌ Not loaded'}
Loaded Files: ${_loadedFiles.length}

${status['writeToken'] != 'Configured' ? '⚠️  Configure GitHub token for write operations.' : ''}
''';

        default:
          return '❌ Unknown command: $cmd\nType /help for available commands.';
      }
    } catch (e) {
      return '❌ Error executing command: $e';
    }
  }

  // Build enhanced conversation history with smart context
  List<ChatMessage> _buildEnhancedConversationHistory() {
    // Include ALL messages for full context, but prioritize recent ones
    final allMessages = _messages
        .skip(_messages.length > 20 ? _messages.length - 20 : 0)
        .map((msg) => ChatMessage(
      content: msg.text,
      isUser: msg.isUser,
      timestamp: msg.timestamp,
    ))
        .toList();

    // Add project awareness prompt at the beginning
    if (_projectContextLoaded && allMessages.isNotEmpty) {
      final contextPrompt = ChatMessage(
        content: '''You are an AI assistant with full awareness of the ${_githubService.repo} codebase. You have access to the project structure and ${_loadedFiles.length} key files. Use this context to provide specific, actionable advice about the code. When discussing code, reference specific files and functions you can see.''',
        isUser: false,
        timestamp: DateTime.now(),
      );
      allMessages.insert(0, contextPrompt);
    }

    return allMessages;
  }

  // Clear conversation
  Future<void> clearConversation() async {
    _messages.clear();
    _projectContextLoaded = false;
    _loadedFiles.clear();

    // Use actual database method
    await _databaseHelper.clearMessages();

    notifyListeners();
  }

  // Private methods
  void _addMessage(ConversationMessage message) {
    _messages.add(message);
    _saveMessage(message);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> _saveMessage(ConversationMessage message) async {
    try {
      // Use actual database method with adapter name
      final adapterName = _currentAdapter?.name ?? 'Unknown';
      await _databaseHelper.insertMessage(message, adapterName);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving message: $e');
      }
    }
  }

  Future<void> _loadConversationHistory() async {
    try {
      // Use actual database method
      final loadedMessages = await _databaseHelper.loadMessages();
      _messages.clear();
      _messages.addAll(loadedMessages);

      // Rebuild loaded files from message content (since metadata isn't in your schema)
      for (final message in _messages) {
        if (message.text.startsWith('🔄 Auto-loaded ') || message.text.startsWith('📄 Auto-loaded ')) {
          // Extract filename from auto-load messages
          final match = RegExp(r'Auto-loaded ([^\s:]+)').firstMatch(message.text);
          if (match != null) {
            _loadedFiles.add(match.group(1)!);
          }
        }
        if (message.text.contains('🎯 Auto-loaded project context')) {
          _projectContextLoaded = true;
        }
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading conversation history: $e');
      }
    }
  }

  // Dispose
  Future<void> dispose() async {
    await _currentAdapter?.dispose();
    super.dispose();
  }
}