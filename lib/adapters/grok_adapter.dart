import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_adapter.dart';

class GrokAdapter implements AIAdapter {
  final String _apiKey;
  final String _baseUrl = 'https://api.x.ai/v1';

  GrokAdapter({required String apiKey}) : _apiKey = apiKey;

  @override
  String get name => 'Grok AI';

  @override
  bool get isAvailable => _apiKey.isNotEmpty;

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
    if (!isAvailable) {
      throw Exception('Grok API key not configured');
    }

    final url = Uri.parse('$_baseUrl/chat/completions');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final apiMessages = messages.map((msg) => {
      'role': msg.role,
      'content': msg.content,
    }).toList();

    final body = jsonEncode({
      'model': 'grok-3',
      'messages': apiMessages,
      'max_tokens': 1000,
      'temperature': 0.7,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content ?? 'No response from Grok';
      } else {
        throw Exception('Grok API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to Grok: $e');
    }
  }

  @override
  Future<void> initialize({Map<String, dynamic>? config}) async {}

  @override
  Future<void> dispose() async {}
}