import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/conversation_service.dart';
import 'services/api_key_service.dart';
import 'services/github_service.dart';
import 'adapters/test_adapter.dart';
import 'adapters/grok_adapter.dart';
import 'adapters/claude_adapter.dart';

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
  final TextEditingController _githubOwnerController = TextEditingController();
  final TextEditingController _githubRepoController = TextEditingController();
  final TextEditingController _githubTokenController = TextEditingController();
  late ConversationService _conversationService;
  bool _showApiKeyInput = false;
  bool _showGitHubConfig = false;
  bool _isInitializing = true;
  String _currentApiKeyType = 'grok'; // 'grok' or 'claude'

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
            _showRestoredMessage('Grok connection restored!');
          }
        } else {
          await _conversationService.setAdapter(TestAdapter());
        }
      } else if (lastAdapter == 'claude') {
        // Try to restore Claude connection
        final savedApiKey = await ApiKeyService.getClaudeApiKey();
        if (savedApiKey != null && savedApiKey.isNotEmpty) {
          await _conversationService.setAdapter(ClaudeAdapter(apiKey: savedApiKey));
          if (mounted) {
            _showRestoredMessage('Claude connection restored!');
          }
        } else {
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

  void _showRestoredMessage(String message) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _apiKeyController.dispose();
    _githubOwnerController.dispose();
    _githubRepoController.dispose();
    _githubTokenController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text;
    if (message.isNotEmpty) {
      _conversationService.sendMessage(message);
      _messageController.clear();
    }
  }

  void _toggleApiKeyInput(String keyType) {
    setState(() {
      _currentApiKeyType = keyType;
      _showApiKeyInput = !_showApiKeyInput;
      _showGitHubConfig = false; // Close GitHub config if open

      // Pre-fill with existing key if available
      if (_showApiKeyInput) {
        _loadExistingApiKey(keyType);
      }
    });
  }

  void _toggleGitHubConfig() {
    setState(() {
      _showGitHubConfig = !_showGitHubConfig;
      _showApiKeyInput = false; // Close API key input if open

      // Pre-fill with existing GitHub settings if available
      if (_showGitHubConfig) {
        _loadExistingGitHubConfig();
      }
    });
  }

  Future<void> _loadExistingApiKey(String keyType) async {
    String? existingKey;
    if (keyType == 'grok') {
      existingKey = await ApiKeyService.getGrokApiKey();
    } else if (keyType == 'claude') {
      existingKey = await ApiKeyService.getClaudeApiKey();
    }

    if (existingKey != null) {
      _apiKeyController.text = existingKey;
    } else {
      _apiKeyController.clear();
    }
  }

  Future<void> _loadExistingGitHubConfig() async {
    final config = await ApiKeyService.getGitHubRepo();
    _githubOwnerController.text = config['owner'] ?? '';
    _githubRepoController.text = config['repo'] ?? '';
    _githubTokenController.text = config['token'] ?? '';
  }

  Future<void> _setGrokAdapter() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      try {
        await ApiKeyService.saveGrokApiKey(apiKey);
        await ApiKeyService.saveLastAdapter('grok');
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

  Future<void> _setClaudeAdapter() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isNotEmpty) {
      try {
        await ApiKeyService.saveClaudeApiKey(apiKey);
        await ApiKeyService.saveLastAdapter('claude');
        await _conversationService.setAdapter(ClaudeAdapter(apiKey: apiKey));

        setState(() {
          _showApiKeyInput = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Claude adapter configured and saved!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save Claude settings: $e')),
          );
        }
      }
    }
  }

  Future<void> _setApiAdapter() async {
    if (_currentApiKeyType == 'grok') {
      await _setGrokAdapter();
    } else if (_currentApiKeyType == 'claude') {
      await _setClaudeAdapter();
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

  Future<void> _saveGitHubConfig() async {
    final owner = _githubOwnerController.text.trim();
    final repo = _githubRepoController.text.trim();
    final token = _githubTokenController.text.trim();

    if (owner.isNotEmpty && repo.isNotEmpty) {
      try {
        await ApiKeyService.saveGitHubRepo(
          owner: owner,
          repo: repo,
          token: token.isNotEmpty ? token : null,
        );

        // Test the connection
        final githubService = GitHubService(
          owner: owner,
          repo: repo,
          token: token.isNotEmpty ? token : null,
        );

        final isConnected = await githubService.testConnection();

        setState(() {
          _showGitHubConfig = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isConnected
                  ? 'GitHub repository connected successfully!'
                  : 'GitHub settings saved (connection test failed)'),
              backgroundColor: isConnected ? Colors.green.shade600 : Colors.orange.shade600,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save GitHub settings: $e')),
          );
        }
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
          const SnackBar(content: Text('All settings cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear settings: $e')),
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
        title: const Text('Morfork MVF - AI Development Platform'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'grok':
                  _toggleApiKeyInput('grok');
                  break;
                case 'claude':
                  _toggleApiKeyInput('claude');
                  break;
                case 'test':
                  _setTestAdapter();
                  break;
                case 'github':
                  _toggleGitHubConfig();
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
                value: 'claude',
                child: Row(
                  children: [
                    Icon(Icons.smart_toy),
                    SizedBox(width: 8),
                    Text('Configure Claude AI'),
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
                value: 'github',
                child: Row(
                  children: [
                    Icon(Icons.code, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('GitHub Integration', style: TextStyle(color: Colors.blue)),
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
                    Text('Clear All Settings', style: TextStyle(color: Colors.red)),
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
                  color: _currentApiKeyType == 'grok' ? Colors.blue.shade50 : Colors.purple.shade50,
                  child: Column(
                    children: [
                      TextField(
                        controller: _apiKeyController,
                        decoration: InputDecoration(
                          labelText: _currentApiKeyType == 'grok' ? 'Grok API Key' : 'Claude API Key',
                          hintText: _currentApiKeyType == 'grok'
                              ? 'Enter your xAI API key'
                              : 'Enter your Anthropic API key',
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _setApiAdapter,
                            child: Text('Connect ${_currentApiKeyType == 'grok' ? 'Grok' : 'Claude'}'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _toggleApiKeyInput(_currentApiKeyType),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              // GitHub Configuration (when visible)
              if (_showGitHubConfig)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.grey.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GitHub Repository Configuration',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Configure access to your repository for file-aware AI conversations',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _githubOwnerController,
                        decoration: const InputDecoration(
                          labelText: 'Repository Owner',
                          hintText: 'e.g., Infinite-Grok',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _githubRepoController,
                        decoration: const InputDecoration(
                          labelText: 'Repository Name',
                          hintText: 'e.g., morfork-mvf',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _githubTokenController,
                        decoration: const InputDecoration(
                          labelText: 'GitHub Token (Optional)',
                          hintText: 'For private repositories',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _saveGitHubConfig,
                            child: const Text('Save & Test Connection'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _toggleGitHubConfig,
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
                    'Start chatting with AI!\n\nTry: "Hello" or configure Claude/Grok from the menu.',
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