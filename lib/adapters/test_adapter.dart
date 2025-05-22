import 'ai_adapter.dart';

/// Simple test implementation of AIAdapter for MVF validation
/// This simulates AI responses without requiring external services
class TestAdapter implements AIAdapter {
  @override
  String get name => 'Test Adapter';

  @override
  bool get isAvailable => true;

  final List<String> _responses = [
    'Hello! I\'m the test AI adapter. How can I help you?',
    'That\'s an interesting question. Let me think about it...',
    'I understand. Here\'s my response to your message.',
    'Great! I\'m processing your request.',
    'Thanks for using the Morfork test adapter!',
  ];

  int _responseIndex = 0;

  @override
  Future<String> sendMessage(String message) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Cycle through predefined responses
    final response = _responses[_responseIndex % _responses.length];
    _responseIndex++;

    // Add the user's message context to the response
    return 'You said: "$message"\n\n$response';
  }

  @override
  Future<void> initialize({Map<String, dynamic>? config}) async {
    // Reset response index on initialization
    _responseIndex = 0;
  }

  @override
  Future<void> dispose() async {
    // Nothing to clean up for test adapter
  }
}
