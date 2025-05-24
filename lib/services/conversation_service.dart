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
    required this.text,
    required this.isUser,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Service that manages conversations using AI adapters with persistent storage
/// Now includes GitHub write operations for AI-assisted development
class ConversationService extends ChangeNotifier {
  AIAdapter? _currentAdapter;
  final List<ConversationMessage> _messages = [];
  bool _isProcessing = false;
  String? _error;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoaded = false;
  GitHubService? _githubService;

  // Pending changes for /diff command
  final Map<String, String> _pendingChanges = {};

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

  /// PUBLIC: Re-initialize GitHub service after config changes
  Future<void> reinitializeGitHub() async {
    await _initializeGitHubService();
    notifyListeners(); // Notify UI that GitHub service may have changed
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

    // Handle GitHub commands (including new write commands)
    if (message.startsWith('/')) {
      await _handleGitHubCommand(message);
      return;
    }

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      // Build conversation history for AI with ENHANCED CONTEXT
      final conversationHistory = _buildConversationHistoryWithContext();

      // Send to AI with SPECIFIC INSTRUCTIONS
      final response = await _currentAdapter!.sendConversation(conversationHistory);

      // Add AI response
      final aiMessage = ConversationMessage(text: response, isUser: false);
      _messages.add(aiMessage);

      try {
        await _dbHelper.insertMessage(aiMessage, _currentAdapter!.name);
      } catch (e) {
        debugPrint('Failed to save AI message: $e');
      }

      // CRITICAL: Check if this AI response should trigger a GitHub action
      await _checkForGitHubActions(response);

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

  /// ENHANCED: Check if AI response should trigger GitHub actions
  Future<void> _checkForGitHubActions(String aiResponse) async {
    if (_pendingChanges.isEmpty) return;

    debugPrint('🔍 Checking for GitHub actions in AI response...');
    debugPrint('📋 Pending changes: ${_pendingChanges.keys.toList()}');

    // Check if AI is responding to a file creation/edit request
    for (final entry in _pendingChanges.entries.toList()) {
      final filename = entry.key;
      final status = entry.value;

      debugPrint('🔍 Checking $filename with status: $status');

      if (status == 'CREATE_PENDING' || status == 'UPDATE_PENDING') {
        // IMPROVED: Look for code blocks with multiple patterns
        final codePatterns = [
          RegExp(r'```dart\n(.*?)\n```', dotAll: true),
          RegExp(r'```\n(.*?)\n```', dotAll: true),
          RegExp(r'```flutter\n(.*?)\n```', dotAll: true),
        ];

        String? extractedCode;
        for (final pattern in codePatterns) {
          final match = pattern.firstMatch(aiResponse);
          if (match != null) {
            extractedCode = match.group(1)?.trim();
            debugPrint('📝 Found code block with pattern: ${pattern.pattern}');
            break;
          }
        }

        if (extractedCode != null && extractedCode.isNotEmpty) {
          // IMPROVED: Better code validation
          if (_isValidDartCode(extractedCode)) {
            debugPrint('✅ Valid Dart code detected, executing GitHub write...');
            await _performGitHubWrite(filename, extractedCode, status);
            _pendingChanges.remove(filename);
            debugPrint('🗑️ Removed $filename from pending changes');
          } else {
            debugPrint('❌ Code validation failed for $filename');
          }
        } else {
          debugPrint('❌ No code block found in AI response');
        }
      }
      // Handle case where we already have content to commit
      else if (status != 'CREATE_PENDING' && status != 'UPDATE_PENDING') {
        // We have actual content, commit it
        if (aiResponse.toLowerCase().contains('commit') ||
            aiResponse.toLowerCase().contains('save') ||
            aiResponse.toLowerCase().contains('write')) {
          debugPrint('✅ Commit request detected, executing GitHub write...');
          await _performGitHubWrite(filename, status, 'UPDATE');
          _pendingChanges.remove(filename);
        }
      }
    }
  }

  /// IMPROVED: Better code validation
  bool _isValidDartCode(String code) {
    final trimmedCode = code.trim();

    // Check for basic Dart patterns
    final dartPatterns = [
      'void ', 'class ', 'import ', 'library ', 'part ',
      'String ', 'int ', 'double ', 'bool ', 'var ',
      'final ', 'const ', 'static ', 'abstract ',
      'extends ', 'implements ', 'with ', 'enum ',
      'typedef ', 'mixin ', '=>', 'async ', 'await'
    ];

    return trimmedCode.isNotEmpty &&
        dartPatterns.any((pattern) => trimmedCode.contains(pattern));
  }

  /// ENHANCED: Actually perform the GitHub write operation with better error handling
  Future<void> _performGitHubWrite(String filename, String content, String operation) async {
    if (_githubService == null || !_githubService!.canWrite) {
      _addSystemMessage('❌ GitHub write not available - token missing or invalid');
      return;
    }

    try {
      _addSystemMessage('📤 Writing to GitHub repository...');
      debugPrint('📤 Starting GitHub write: $filename ($operation)');

      GitHubWriteResult result;

      if (operation == 'CREATE_PENDING') {
        debugPrint('📝 Creating new file: $filename');
        result = await _githubService!.createFile(
          filePath: filename,
          content: content,
          commitMessage: 'Add $filename via Morfork AI Assistant',
        );
      } else {
        debugPrint('✏️ Updating existing file: $filename');
        result = await _githubService!.updateFile(
          filePath: filename,
          content: content,
          commitMessage: 'Update $filename via Morfork AI Assistant',
        );
      }

      // ENHANCED SUCCESS MESSAGE
      _addSystemMessage('''
✅ **GitHub Operation Successful!**

📋 **File Details:**
• File: `$filename`
• Operation: ${operation == 'CREATE_PENDING' ? 'CREATED' : 'UPDATED'}
• Lines: ${content.split('\n').length}

📝 **Commit Information:**
• Message: "${result.commitMessage}"
• SHA: `${result.commitSha?.substring(0, 7) ?? 'N/A'}`
• Repository: ${_githubService!.owner}/${_githubService!.repo}

🔗 **View File:** [${filename}](https://github.com/${_githubService!.owner}/${_githubService!.repo}/blob/main/$filename)

🎉 File has been successfully committed to your repository!
''');

      debugPrint('✅ GitHub write completed successfully');

    } catch (e) {
      debugPrint('❌ GitHub write failed: $e');
      _addSystemMessage('''
❌ **GitHub Write Failed**

**Error:** $e

**Troubleshooting:**
• Verify your GitHub token has write permissions
• Check if the repository exists and is accessible
• Ensure the file path is valid
• Try the /status command to check GitHub connection

Use `/status` to verify your GitHub configuration.
''');
    }
  }

  /// ENHANCED: Build conversation history WITH GITHUB CONTEXT INSTRUCTIONS
  List<ChatMessage> _buildConversationHistoryWithContext() {
    // Get last 15 messages for context
    final recentMessages = _messages.length > 15
        ? _messages.skip(_messages.length - 15).toList()
        : _messages.toList();

    final chatMessages = <ChatMessage>[];

    // ADD CRITICAL SYSTEM CONTEXT if we have pending GitHub operations
    if (_pendingChanges.isNotEmpty) {
      final pendingFiles = _pendingChanges.keys.join(', ');
      chatMessages.add(ChatMessage(
        content: '''SYSTEM CONTEXT: You are working with the Morfork AI development platform that has direct GitHub integration. 

PENDING FILE OPERATIONS: $pendingFiles

CRITICAL INSTRUCTIONS:
- When providing code, use proper code blocks with ```dart or ``` 
- Do NOT generate fake GitHub success messages
- Do NOT say things like "committed to GitHub" or "file created successfully"
- The system will automatically handle GitHub operations after you provide the code
- Focus on generating high-quality, working Dart/Flutter code
- Let the system handle all GitHub operations and success/failure messages

Your job is to provide excellent code. The system will handle the rest.''',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    }

    // Include ALL messages, including system messages with project context
    chatMessages.addAll(recentMessages
        .map((msg) => ChatMessage(
      content: msg.text,
      isUser: msg.isUser,
      timestamp: msg.timestamp,
    ))
        .toList());

    return chatMessages;
  }

  // Enhanced GitHub command handling with write operations
  Future<void> _handleGitHubCommand(String command) async {
    if (_githubService == null) {
      _addSystemMessage('❌ GitHub not configured. Use the menu to set up GitHub integration.');
      return;
    }

    _isProcessing = true;
    notifyListeners();

    try {
      final parts = command.split(' ');
      final cmd = parts[0].toLowerCase();

      switch (cmd) {
      // Existing read commands
        case '/read':
          if (parts.length < 2) {
            _addSystemMessage('**Usage:** `/read <filename>`\n**Example:** `/read lib/main.dart`');
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

      // Enhanced write commands
        case '/create':
          if (parts.length < 2) {
            _addSystemMessage('**Usage:** `/create <filename>`\n**Example:** `/create lib/utils/helper.dart`');
            break;
          }
          final filename = parts.sublist(1).join(' ');
          await _createFileInteractive(filename);
          break;
        case '/edit':
          if (parts.length < 2) {
            _addSystemMessage('**Usage:** `/edit <filename>`\n**Example:** `/edit lib/main.dart`');
            break;
          }
          final filename = parts.sublist(1).join(' ');
          await _editFileInteractive(filename);
          break;
        case '/delete':
          if (parts.length < 2) {
            _addSystemMessage('**Usage:** `/delete <filename>`\n**Example:** `/delete lib/old_file.dart`');
            break;
          }
          final filename = parts.sublist(1).join(' ');
          await _deleteFileInteractive(filename);
          break;
        case '/diff':
          await _showPendingChanges();
          break;
        case '/write':
          if (parts.length < 2) {
            _addSystemMessage('**Usage:** `/write <filename>`\n**Example:** `/write lib/new_component.dart`');
            break;
          }
          final filename = parts.sublist(1).join(' ');
          await _writeFileInteractive(filename);
          break;
        case '/status':
          await _showGitHubStatus();
          break;
        case '/help':
          _showGitHubHelp();
          break;
        default:
          _addSystemMessage('❌ Unknown command: `$cmd`\nType `/help` for available commands.');
      }
    } catch (e) {
      _addSystemMessage('❌ GitHub command error: $e');
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // READ OPERATIONS (Existing)
  // ============================================================================

  void _addSystemMessage(String message) {
    final systemMessage = ConversationMessage(text: '🤖 **System:** $message', isUser: false);
    _messages.add(systemMessage);
    notifyListeners();
    _dbHelper.insertMessage(systemMessage, 'System').catchError((e) {
      debugPrint('Failed to save system message: $e');
    });
  }

  Future<void> _readFile(String filename) async {
    try {
      final content = await _githubService!.readFile(filename);
      _addSystemMessage('📄 **File:** `$filename`\n\n```dart\n$content\n```');
    } catch (e) {
      _addSystemMessage('❌ Failed to read `$filename`: $e');
    }
  }

  Future<void> _showProjectStructure() async {
    try {
      final files = await _githubService!.getFileTree();
      final structure = _buildFileTree(files);
      _addSystemMessage('📁 **Project Structure:**\n\n```\n$structure\n```');
    } catch (e) {
      _addSystemMessage('❌ Failed to get project structure: $e');
    }
  }

  Future<void> _listFiles(String? path) async {
    try {
      final files = await _githubService!.getFileTree(path: path);
      final fileList = files.map((f) => '${f.isDirectory ? '📁' : '📄'} `${f.name}`').join('\n');
      final pathStr = path ?? 'root';
      _addSystemMessage('📋 **Files in $pathStr:**\n\n$fileList');
    } catch (e) {
      _addSystemMessage('❌ Failed to list files: $e');
    }
  }

  Future<void> _showRecentCommits() async {
    try {
      final commits = await _githubService!.getRecentCommits(count: 5);
      final commitList = commits.map((c) =>
      '• **${c['commit']['message']}**\n  by ${c['commit']['author']['name']} (`${c['sha'].substring(0, 7)}`)'
      ).join('\n\n');
      _addSystemMessage('📝 **Recent Commits:**\n\n$commitList');
    } catch (e) {
      _addSystemMessage('❌ Failed to get recent commits: $e');
    }
  }

  // ============================================================================
  // WRITE OPERATIONS (Enhanced)
  // ============================================================================

  Future<void> _createFileInteractive(String filename) async {
    if (!_githubService!.canWrite) {
      _addSystemMessage('❌ GitHub token with write permissions required for file creation.');
      return;
    }

    try {
      // Check if file exists
      final exists = await _githubService!.fileExists(filename);
      if (exists) {
        _addSystemMessage('⚠️ **File already exists:** `$filename`\n\nUse `/edit` to modify existing files.');
        return;
      }

      _addSystemMessage('''
📝 **Ready to create:** `$filename`

**Next step:** Describe what you want in this file. For example:
• "Create a simple Flutter widget with a button"
• "Make a utility function for string validation"
• "Create a data model class for User"

I'll generate the code and automatically commit it to GitHub!
''');

      // Store the pending filename for the next AI response
      _pendingChanges[filename] = 'CREATE_PENDING';
      debugPrint('📋 Added $filename to pending changes (CREATE_PENDING)');

    } catch (e) {
      _addSystemMessage('❌ Failed to prepare file creation: $e');
    }
  }

  Future<void> _editFileInteractive(String filename) async {
    if (!_githubService!.canWrite) {
      _addSystemMessage('❌ GitHub token with write permissions required for file editing.');
      return;
    }

    try {
      // Read current file content
      final content = await _githubService!.readFile(filename);

      _addSystemMessage('''
✏️ **Ready to edit:** `$filename`

**Current content:**
```dart
$content
```

**Next step:** Describe the changes you want to make. For example:
• "Add error handling to the main method"
• "Refactor this code to use async/await"
• "Add a new method called calculateTotal"

I'll modify the code and automatically commit the changes!
''');

      // Store the current content for modification
      _pendingChanges[filename] = 'UPDATE_PENDING';
      debugPrint('📋 Added $filename to pending changes (UPDATE_PENDING)');

    } catch (e) {
      _addSystemMessage('❌ Failed to read file for editing: $e');
    }
  }

  Future<void> _writeFileInteractive(String filename) async {
    if (!_githubService!.canWrite) {
      _addSystemMessage('❌ GitHub token with write permissions required for file operations.');
      return;
    }

    try {
      final exists = await _githubService!.fileExists(filename);
      final action = exists ? 'update' : 'create';

      _addSystemMessage('''
📝 **Ready to $action:** `$filename`

**Next step:** Provide the complete file content in your next message.

I'll $action the file with your specified content and commit it automatically.
''');

      // Mark for write operation
      _pendingChanges[filename] = exists ? 'UPDATE_PENDING' : 'CREATE_PENDING';
      debugPrint('📋 Added $filename to pending changes (${exists ? 'UPDATE_PENDING' : 'CREATE_PENDING'})');

    } catch (e) {
      _addSystemMessage('❌ Failed to prepare file operation: $e');
    }
  }

  Future<void> _deleteFileInteractive(String filename) async {
    if (!_githubService!.canWrite) {
      _addSystemMessage('❌ GitHub token with write permissions required for file deletion.');
      return;
    }

    try {
      // Check if file exists
      final exists = await _githubService!.fileExists(filename);
      if (!exists) {
        _addSystemMessage('❌ File not found: `$filename`');
        return;
      }

      // Delete the file immediately (no AI interaction needed)
      final result = await _githubService!.deleteFile(
        filePath: filename,
        commitMessage: 'Delete $filename via Morfork AI',
      );

      _addSystemMessage('''
🗑️ **Successfully deleted:** `$filename`

**Commit:** ${result.commitMessage}
**SHA:** `${result.commitSha?.substring(0, 7) ?? 'N/A'}`
''');

    } catch (e) {
      _addSystemMessage('❌ Failed to delete file: $e');
    }
  }

  Future<void> _showPendingChanges() async {
    if (_pendingChanges.isEmpty) {
      _addSystemMessage('📋 No pending changes.');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('📋 **Pending Changes:**\n');

    for (final entry in _pendingChanges.entries) {
      final filename = entry.key;
      final status = entry.value;

      if (status == 'CREATE_PENDING') {
        buffer.writeln('📝 **CREATE:** `$filename`');
      } else if (status == 'UPDATE_PENDING') {
        buffer.writeln('✏️ **UPDATE:** `$filename`');
      } else {
        buffer.writeln('📄 **MODIFY:** `$filename`');
      }
    }

    _addSystemMessage(buffer.toString());
  }

  Future<void> _showGitHubStatus() async {
    try {
      final canWrite = _githubService!.canWrite;
      final hasWritePerms = await _githubService!.testWritePermissions();
      final repoInfo = await _githubService!.getRepoInfo();

      _addSystemMessage('''
📊 **GitHub Status:**

**Repository:** `${repoInfo['full_name']}`
**Default Branch:** `${repoInfo['default_branch']}`
**Write Token:** ${canWrite ? '✅ Configured' : '❌ Missing'}
**Write Permissions:** ${hasWritePerms ? '✅ Verified' : '❌ No push access'}
**Pending Changes:** ${_pendingChanges.length}

${!canWrite ? '\n⚠️ Configure GitHub token for write operations.' : ''}
${canWrite && !hasWritePerms ? '\n⚠️ Token lacks push permissions to this repository.' : ''}
''');

    } catch (e) {
      _addSystemMessage('❌ Failed to get GitHub status: $e');
    }
  }

  void _showGitHubHelp() {
    _addSystemMessage('''
🔧 **GitHub Commands:**

**📖 READ OPERATIONS:**
• `/read <filename>` - Read a file from the repository
• `/structure` - Show the project file structure  
• `/files [path]` - List files in a directory
• `/commits` - Show recent commits

**✏️ WRITE OPERATIONS:**
• `/create <filename>` - Create a new file with AI assistance
• `/edit <filename>` - Modify an existing file with AI
• `/write <filename>` - Create or update a file 
• `/delete <filename>` - Delete a file from repository

**🔧 UTILITY:**
• `/diff` - Show pending changes
• `/status` - Show GitHub connection status
• `/help` - Show this help message

**Examples:**
• `/read lib/main.dart`
• `/create lib/utils/helper.dart`
• `/edit pubspec.yaml`
• `/structure`
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

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  Future<void> clearConversation() async {
    try {
      await _dbHelper.clearMessages();
      _messages.clear();
      _pendingChanges.clear();
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