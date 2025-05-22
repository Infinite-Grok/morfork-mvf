import 'package:flutter/foundation.dart';
import '../adapters/ai_adapter.dart';
import '../database/database_helper.dart';

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
/// This is the core service that coordinates between UI, AI adapters, and database
class ConversationService extends ChangeNotifier {
  AIAdapter? _currentAdapter;
  final List<ConversationMessage> _messages = [];
  bool _isProcessing = false;
  String? _error;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoaded = false;

  /// Current AI adapter being used
  AIAdapter? get currentAdapter => _currentAdapter;

  /// List of all conversation messages
  List<ConversationMessage> get messages => List.unmodifiable(_messages);

  /// Whether a request is currently being processed
  bool get isProcessing => _isProcessing;

  /// Current error message, if any
  String? get error => _error;

  /// Whether messages have been loaded from database
  bool get isLoaded => _isLoaded;

  /// Load conversation history from database
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

  /// Set the AI adapter to use for conversations
  Future<void> setAdapter(AIAdapter adapter) async {
    try {
      _error = null;
      await adapter.initialize();
      _currentAdapter = adapter;

      // Load conversation history when adapter is set (if not already loaded)
      if (!_isLoaded) {
        await loadConversationHistory();
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize adapter: $e';
      notifyListeners();
    }
  }

  /// Send a message through the current adapter
  Future<void> sendMessage(String message) async {
    if (_currentAdapter == null) {
      _error = 'No AI adapter configured';
      notifyListeners();
      return;
    }

    if (message.trim().isEmpty) {
      return;
    }

    // Create and add user message
    final userMessage = ConversationMessage(text: message, isUser: true);

    _messages.add(userMessage);

    // Save user message to database
    try {
      await _dbHelper.insertMessage(userMessage, _currentAdapter!.name);
    } catch (e) {
      debugPrint('Failed to save user message: $e');
    }

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      // Get AI response
      final response = await _currentAdapter!.sendMessage(message);

      // Create and add AI response
      final aiMessage = ConversationMessage(text: response, isUser: false);

      _messages.add(aiMessage);

      // Save AI response to database
      try {
        await _dbHelper.insertMessage(aiMessage, _currentAdapter!.name);
      } catch (e) {
        debugPrint('Failed to save AI message: $e');
      }
    } catch (e) {
      _error = 'Failed to get AI response: $e';
      // Add error message to conversation
      final errorMessage = ConversationMessage(
        text: 'Error: $e',
        isUser: false,
      );
      _messages.add(errorMessage);

      // Save error message to database
      try {
        await _dbHelper.insertMessage(
          errorMessage,
          _currentAdapter?.name ?? 'Unknown',
        );
      } catch (dbError) {
        debugPrint('Failed to save error message: $dbError');
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Clear the conversation history (both memory and database)
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

  /// Get total message count from database
  Future<int> getMessageCount() async {
    try {
      return await _dbHelper.getMessageCount();
    } catch (e) {
      debugPrint('Failed to get message count: $e');
      return 0;
    }
  }

  /// Clean up old messages (older than specified days)
  Future<void> cleanupOldMessages(int daysToKeep) async {
    try {
      await _dbHelper.deleteOldMessages(daysToKeep);
      // Reload messages to reflect changes
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
