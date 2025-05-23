/// Abstract interface for AI adapters in the Morfork system
/// This provides a universal interface that can work with any AI provider
abstract class AIAdapter {
  /// Name identifier for this adapter
  String get name;

  /// Whether this adapter is currently available/configured
  bool get isAvailable;

  /// Send a single message to the AI and get a response (legacy method)
  /// Returns the AI's response text or throws an exception on error
  Future<String> sendMessage(String message);

  /// Send a conversation with full message history (preferred method)
  /// Messages should be in chronological order with alternating user/assistant roles
  Future<String> sendConversation(List<ChatMessage> messages);

  /// Optional: Initialize the adapter with configuration
  Future<void> initialize({Map<String, dynamic>? config}) async {
    // Default implementation does nothing
  }

  /// Optional: Clean up resources
  Future<void> dispose() async {
    // Default implementation does nothing
  }
}

/// Represents a message in a conversation for AI processing
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
  });

  /// Convert to role-based format for AI APIs
  String get role => isUser ? 'user' : 'assistant';
}