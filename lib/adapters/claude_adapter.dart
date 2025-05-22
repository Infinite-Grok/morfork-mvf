import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_adapter.dart';

/// Claude AI adapter implementation
/// Connects to Anthropic's Claude API for advanced AI conversations
class ClaudeAdapter implements AIAdapter {
  final String _apiKey;
  final String _baseUrl = 'https://api.anthropic.com/v1';
  final String _model;

  ClaudeAdapter({
    required String apiKey,
    String model = 'claude-3-5-sonnet-20241022',
  }) : _apiKey = apiKey, _model = model;

  @override
  String get name => 'Claude AI ($_model)';

  @override
  bool get isAvailable => _apiKey.isNotEmpty;

  @override
  Future<String> sendMessage(String message) async {
    if (!isAvailable) {
      throw Exception('Claude API key not configured');
    }

    final url = Uri.parse('$_baseUrl/messages');

    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': _apiKey,
      'anthropic-version': '2023-06-01',
    };

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 4000,
      'messages': [
        {
          'role': 'user',
          'content': message,
        }
      ],
    });

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Claude API returns content in a different format
        if (data['content'] != null && data['content'].isNotEmpty) {
          final content = data['content'][0]['text'];
          return content ?? 'No response from Claude';
        } else {
          return 'Empty response from Claude';
        }
      } else {
        throw Exception('Claude API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to Claude: $e');
    }
  }

  @override
  Future<void> initialize({Map<String, dynamic>? config}) async {
    // Verify API key is working with a simple test if needed
    if (isAvailable) {
      // Could add a test call here if needed
    }
  }

  @override
  Future<void> dispose() async {
    // Nothing to clean up for HTTP adapter
  }
}