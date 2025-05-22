import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/conversation_service.dart';
import 'adapters/test_adapter.dart';

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
  late ConversationService _conversationService;

  @override
  void initState() {
    super.initState();
    // Initialize with test adapter after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _conversationService = Provider.of<ConversationService>(
        context,
        listen: false,
      );
      _conversationService.setAdapter(TestAdapter());
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      _conversationService.sendMessage(message);
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Morfork MVF - AI Adapter Test'),
      ),
      body: Consumer<ConversationService>(
        builder: (context, service, child) {
          return Column(
            children: [
              // Status bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                color:
                    service.currentAdapter?.isAvailable == true
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                child: Text(
                  service.currentAdapter != null
                      ? 'Connected: ${service.currentAdapter!.name}'
                      : 'No adapter connected',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        service.currentAdapter?.isAvailable == true
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                  ),
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
                child:
                    service.messages.isEmpty
                        ? const Center(
                          child: Text(
                            'Send a message to test the AI adapter!',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
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

              // Input area
              Container(
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
          color:
              message.isUser
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
                color:
                    message.isUser
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 12,
                color:
                    message.isUser
                        ? Theme.of(
                          context,
                        ).colorScheme.onPrimary.withOpacity(0.7)
                        : Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
