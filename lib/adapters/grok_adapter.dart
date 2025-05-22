import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_adapter.dart';

/// Grok AI adapter implementation
/// Connects to xAI's Grok API for real AI conversations
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
    if (!isAvailable) {
      throw Exception('Grok API key not configured');
    }

    final url = Uri.parse('$_baseUrl/chat/completions');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = jsonEncode({
      'model': 'grok-3',
      'messages': [
        {'role': 'user', 'content': message},
      ],
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
        throw Exception(
          'Grok API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to connect to Grok: $e');
    }
  }

  @override
  Future<void> initialize({Map<String, dynamic>? config}) async {
    // Verify API key is working with a simple test
    if (isAvailable) {
      // Could add a test call here if needed
    }
  }

  @override
  Future<void> dispose() async {
    // Nothing to clean up for HTTP adapter
  }
}
