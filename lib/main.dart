import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/conversation_service.dart';
import 'adapters/test_adapter.dart';
import 'adapters/grok_adapter.dart';

void main() {
  runApp(const MorforkApp());
}

class MorforkApp extends StatelessWidget {
  const MorforkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ConversationService(),
      child: MaterialApp(
        title: 'Morfork MVF',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const ConversationScreen(),
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  late ConversationService _conversationService;
  bool _showApiKeyInput = false;

  @override
  void initState() {
    super.initState();
    // Initialize with test adapter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _conversationService = Provider.of<ConversationService>(context, listen: false);
      _conversationService.setAdapter(TestAdapter());
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      _conversationService.sendMessage(message);
      _messageController.clear();
    }
  }

  void _toggleApiKeyInput() {
    setState(() {
      _showApiKeyInput = !_showApiKeyInput;
    });
  }

  void _setGrokAdapter() {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      _conversationService.setAdapter(GrokAdapter(apiKey: apiKey));
      setState(() {
        _showApiKeyInput = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grok adapter configured!')),
      );
    }
  }

  void _setTestAdapter() {
    _conversationService.setAdapter(TestAdapter());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test adapter active')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Morfork MVF - AI Adapter Test'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'grok':
                  _toggleApiKeyInput();
                  break;
                case 'test':
                  _setTestAdapter();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'grok',
                child: Row(
                  children: [
                    Icon(Icons.psychology),
                    SizedBox(width: 8),
                    Text('Use Grok AI'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'test',
                child: Row(
                  children: [
                    Icon(Icons.science),
                    SizedBox(width: 8),
                    Text('Use Test Adapter'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<ConversationService>(
        builder: (context, service, child) {
          return Column(
            children: [
              // Status bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                color: service.currentAdapter?.isAvailable == true
                    ? Colors.green.shade100
                    : Colors.red.shade100,
                child: Text(
                  service.currentAdapter != null
                      ? 'Connected: ${service.currentAdapter!.name}'
                      : 'No adapter connected',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: service.currentAdapter?.isAvailable == true
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // API Key input (when visible)
              if (_showApiKeyInput)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.blue.shade50,
                  child: Column(
                    children: [
                      TextField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Grok API Key',
                          hintText: 'Enter your xAI API key',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _setGrokAdapter,
                            child: const Text('Connect Grok'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _toggleApiKeyInput,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Error display
              if (service.error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8.0),
                  color: Colors.red.shade50,
                  child: Text(
                    'Error: ${service.error}',
                    style: TextStyle(color: Colors.red.shade800),
                  ),
                ),

              // Messages list
              Expanded(
                child: !service.isLoaded
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading conversation history...'),
                    ],
                  ),
                )
                    : service.messages.isEmpty
                    ? const Center(
                  child: Text(
                    'Send a message to start chatting!\n\nYour conversation will be saved automatically.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: service.messages.length,
                  itemBuilder: (context, index) {
                    final message = service.messages[index];
                    return MessageBubble(message: message);
                  },
                ),
              ),

              // Processing indicator
              if (service.isProcessing)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('AI is thinking...'),
                    ],
                  ),
                ),

              // Input area with SafeArea protection
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          enabled: !service.isProcessing,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: service.isProcessing ? null : _sendMessage,
                        icon: const Icon(Icons.send),
                      ),
                      IconButton(
                        onPressed: service.clearConversation,
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear conversation',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class MessageBubble extends StatelessWidget {
  final ConversationMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: message.isUser
                    ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                    : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}