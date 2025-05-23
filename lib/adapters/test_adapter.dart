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
    final conversation = [
      ChatMessage(
        content: message,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    ];
    return await sendConversation(conversation);
  }

  @override
  Future<String> sendConversation(List<ChatMessage> messages) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final lastMessage = messages.where((m) => m.isUser).lastOrNull;
    final userMessage = lastMessage?.content ?? 'No message';

    final response = _responses[_responseIndex % _responses.length];
    _responseIndex++;

    String contextualResponse = response;
    if (userMessage.toLowerCase().contains('name') &&
        messages.any((m) => m.content.toLowerCase().contains('jonathan'))) {
      contextualResponse = 'Based on our conversation, your name is Jonathan! $response';
    }

    return 'You said: "$userMessage"\n\n$contextualResponse';
  }

  @override
  Future<void> initialize({Map<String, dynamic>? config}) async {
    _responseIndex = 0;
  }

  @override
  Future<void> dispose() async {}
}