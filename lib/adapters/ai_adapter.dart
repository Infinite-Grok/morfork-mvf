/// Abstract interface for AI adapters in the Morfork system
/// This provides a universal interface that can work with any AI provider
abstract class AIAdapter {
  /// Name identifier for this adapter
  String get name;

  /// Whether this adapter is currently available/configured
  bool get isAvailable;

  /// Send a message to the AI and get a response
  /// Returns the AI's response text or throws an exception on error
  Future<String> sendMessage(String message);

  /// Optional: Initialize the adapter with configuration
  Future<void> initialize({Map<String, dynamic>? config}) async {
    // Default implementation does nothing
  }

  /// Optional: Clean up resources
  Future<void> dispose() async {
    // Default implementation does nothing
  }
}