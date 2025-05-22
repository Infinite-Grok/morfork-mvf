import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../services/conversation_service.dart';

/// SQLite database helper for conversation persistence
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'morfork_conversations.db');

    return await openDatabase(path, version: 1, onCreate: _createDatabase);
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        adapter_name TEXT NOT NULL
      )
    ''');
  }

  /// Save a conversation message to the database
  Future<int> insertMessage(
    ConversationMessage message,
    String adapterName,
  ) async {
    final db = await database;

    return await db.insert('conversations', {
      'text': message.text,
      'is_user': message.isUser ? 1 : 0,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'adapter_name': adapterName,
    });
  }

  /// Load all conversation messages from the database
  Future<List<ConversationMessage>> loadMessages() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) {
      return ConversationMessage(
        text: map['text'] as String,
        isUser: (map['is_user'] as int) == 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      );
    }).toList();
  }

  /// Clear all conversation messages
  Future<void> clearMessages() async {
    final db = await database;
    await db.delete('conversations');
  }

  /// Get count of messages in database
  Future<int> getMessageCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM conversations',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Delete messages older than specified days
  Future<void> deleteOldMessages(int daysToKeep) async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(Duration(days: daysToKeep));

    await db.delete(
      'conversations',
      where: 'timestamp < ?',
      whereArgs: [cutoffTime.millisecondsSinceEpoch],
    );
  }

  /// Close the database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
