import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/conversation_service.dart';
import 'services/api_key_service.dart';
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
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialize the app by loading saved preferences and API keys
  Future<void> _initializeApp() async {
    _conversationService = Provider.of<ConversationService>(context, listen: false);

    try {
      // Check what adapter was used last time
      final lastAdapter = await ApiKeyService.getLastAdapter();

      if (lastAdapter == 'grok') {
        // Try to restore Grok connection
        final savedApiKey = await ApiKeyService.getGrokApiKey();
        if (savedApiKey != null && savedApiKey.isNotEmpty) {
          await _conversationService.setAdapter(GrokAdapter(apiKey: savedApiKey));
          if (mounted) {
            // Show success message after a brief delay to ensure UI is ready
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Grok connection restored!'),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
                  ),
                );
              }
            });
          }
        } else {
          // Fallback to test adapter
          await _conversationService.setAdapter(TestAdapter());
        }
      } else {
        // Default to test adapter
        await _conversationService.setAdapter(TestAdapter());
      }
    } catch (e) {
      // Fallback to test adapter on any error
      await _conversationService.setAdapter(TestAdapter());
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
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
      // Pre-fill with existing key if available
      if (_showApiKeyInput) {
        _loadExistingApiKey();
      }
    });
  }

  Future<void> _loadExistingApiKey() async {
    final existingKey = await ApiKeyService.getGrokApiKey();
    if (existingKey != null) {
      _apiKeyController.text = existingKey;
    }
  }

  Future<void> _setGrokAdapter() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      try {
        // Save the API key securely
        await ApiKeyService.saveGrokApiKey(apiKey);
        await ApiKeyService.saveLastAdapter('grok');

        // Set the adapter
        await _conversationService.setAdapter(GrokAdapter(apiKey: apiKey));

        setState(() {
          _showApiKeyInput = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grok adapter configured and saved!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save Grok settings: $e')),
          );
        }
      }
    }
  }

  Future<void> _setTestAdapter() async {
    try {
      await ApiKeyService.saveLastAdapter('test');
      await _conversationService.setAdapter(TestAdapter());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test adapter active')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch to test adapter: $e')),
        );
      }
    }
  }

  Future<void> _clearConversationWithConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Conversation'),
          content: const Text(
            'Are you sure you want to delete all messages? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _conversationService.clearConversation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation cleared')),
        );
      }
    }
  }

  Future<void> _clearApiKeys() async {
    try {
      await ApiKeyService.clearAll();
      await _conversationService.setAdapter(TestAdapter());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All API keys cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear API keys: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Morfork...'),
            ],
          ),
        ),
      );
    }

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
                case 'clear_conversation':
                  _clearConversationWithConfirmation();
                  break;
                case 'clear_keys':
                  _clearApiKeys();
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
                    Text('Configure Grok AI'),
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
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_conversation',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Clear Conversation', style: TextStyle(color: Colors.orange)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_keys',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All API Keys', style: TextStyle(color: Colors.red)),
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
              : Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color: message.isUser
                    ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}