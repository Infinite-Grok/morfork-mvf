import 'package:flutter/foundation.dart';
import '../adapters/ai_adapter.dart';

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

/// Service that manages conversations using AI adapters
/// This is the core service that coordinates between UI and AI adapters
class ConversationService extends ChangeNotifier {
  AIAdapter? _currentAdapter;
  final List<ConversationMessage> _messages = [];
  bool _isProcessing = false;
  String? _error;

  /// Current AI adapter being used
  AIAdapter? get currentAdapter => _currentAdapter;

  /// List of all conversation messages
  List<ConversationMessage> get messages => List.unmodifiable(_messages);

  /// Whether a request is currently being processed
  bool get isProcessing => _isProcessing;

  /// Current error message, if any
  String? get error => _error;

  /// Set the AI adapter to use for conversations
  Future<void> setAdapter(AIAdapter adapter) async {
    try {
      _error = null;
      await adapter.initialize();
      _currentAdapter = adapter;
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

    // Add user message
    _messages.add(ConversationMessage(text: message, isUser: true));

    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      // Get AI response
      final response = await _currentAdapter!.sendMessage(message);

      // Add AI response
      _messages.add(ConversationMessage(text: response, isUser: false));
    } catch (e) {
      _error = 'Failed to get AI response: $e';
      // Add error message to conversation
      _messages.add(ConversationMessage(text: 'Error: $e', isUser: false));
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Clear the conversation history
  void clearConversation() {
    _messages.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _currentAdapter?.dispose();
    super.dispose();
  }
}
