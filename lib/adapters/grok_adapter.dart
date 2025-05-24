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

    // Build enhanced messages with project context
    final apiMessages = _buildGrokMessages(messages);

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

  /// Build Grok-specific message format with enhanced context
  List<Map<String, dynamic>> _buildGrokMessages(List<ChatMessage> messages) {
    final apiMessages = <Map<String, dynamic>>[];

    // Add system context if we have project information
    if (_hasProjectContext(messages)) {
      apiMessages.add({
        'role': 'system',
        'content': _buildProjectContextPrompt(messages),
      });
    }

    // Add conversation messages
    for (final msg in messages) {
      // Skip system messages that were used to build context
      if (msg.content.startsWith('🤖 System:') && _isProjectData(msg.content)) {
        continue; // Already included in context prompt
      }

      apiMessages.add({
        'role': msg.role,
        'content': msg.content,
      });
    }

    return apiMessages;
  }

  /// Check if conversation contains project context
  bool _hasProjectContext(List<ChatMessage> messages) {
    return messages.any((msg) =>
    msg.content.startsWith('🤖 System:') && _isProjectData(msg.content));
  }

  /// Check if message contains project data
  bool _isProjectData(String content) {
    return content.contains('📄 File:') ||
        content.contains('📁 Project Structure:') ||
        content.contains('📋 Files in') ||
        content.contains('📝 Recent Commits:');
  }

  /// Build comprehensive project context prompt for Grok
  String _buildProjectContextPrompt(List<ChatMessage> messages) {
    final context = StringBuffer();

    context.writeln('MORFORK AI DEVELOPMENT PLATFORM CONTEXT:');
    context.writeln('');
    context.writeln('You are an AI assistant working with the Morfork platform, a revolutionary');
    context.writeln('AI development tool that provides:');
    context.writeln('- Universal AI adapter system (works with any AI provider)');
    context.writeln('- File-aware conversations with direct GitHub integration');
    context.writeln('- Cross-platform support (Flutter mobile and web)');
    context.writeln('- Real-time codebase access and modification capabilities');
    context.writeln('');

    // Extract and include project information
    final projectInfo = StringBuffer();
    for (final msg in messages) {
      if (msg.content.startsWith('🤖 System:') && _isProjectData(msg.content)) {
        // Clean up the system message format for Grok
        final cleanContent = msg.content
            .replaceFirst('🤖 System: ', '')
            .trim();
        projectInfo.writeln(cleanContent);
        projectInfo.writeln('');
      }
    }

    if (projectInfo.isNotEmpty) {
      context.writeln('CURRENT PROJECT STATE:');
      context.write(projectInfo.toString());
    }

    context.writeln('INSTRUCTIONS:');
    context.writeln('- You have full access to the project files and structure shown above');
    context.writeln('- Reference specific files, code patterns, and project details in your responses');
    context.writeln('- Provide actionable development advice based on the actual codebase');
    context.writeln('- Use the /read, /structure, /files, and /commits commands when you need more information');
    context.writeln('');

    return context.toString();
  }

  @override
  Future<void> initialize({Map<String, dynamic>? config}) async {}

  @override
  Future<void> dispose() async {}
}