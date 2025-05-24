import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../services/conversation_service.dart';

// Web-specific imports
import 'package:flutter/foundation.dart' show kIsWeb;

/// SQLite database helper for conversation persistence
/// Uses in-memory storage for web, SQLite for mobile
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  // Web fallback: in-memory storage
  static List<Map<String, dynamic>> _webMessages = [];

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database?> get database async {
    if (kIsWeb) {
      // For web, we use in-memory storage
      return null;
    }

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

  /// Save a conversation message to storage
  Future<int> insertMessage(
      ConversationMessage message,
      String adapterName,
      ) async {
    try {
      if (kIsWeb) {
        return _insertMessageWeb(message, adapterName);
      } else {
        return await _insertMessageMobile(message, adapterName);
      }
    } catch (e) {
      print('Database insert error: $e');
      return -1;
    }
  }

  /// Web implementation using in-memory storage
  int _insertMessageWeb(ConversationMessage message, String adapterName) {
    final id = DateTime.now().millisecondsSinceEpoch;

    _webMessages.add({
      'id': id,
      'text': message.text,
      'is_user': message.isUser ? 1 : 0,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'adapter_name': adapterName,
    });

    return id;
  }

  /// Mobile implementation using SQLite
  Future<int> _insertMessageMobile(ConversationMessage message, String adapterName) async {
    final db = await database;
    if (db == null) return -1;

    return await db.insert('conversations', {
      'text': message.text,
      'is_user': message.isUser ? 1 : 0,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'adapter_name': adapterName,
    });
  }

  /// Load all conversation messages from storage
  Future<List<ConversationMessage>> loadMessages() async {
    try {
      if (kIsWeb) {
        return _loadMessagesWeb();
      } else {
        return await _loadMessagesMobile();
      }
    } catch (e) {
      print('Database load error: $e');
      return [];
    }
  }

  /// Web implementation
  List<ConversationMessage> _loadMessagesWeb() {
    return _webMessages.map((data) {
      return ConversationMessage(
        text: data['text'] as String,
        isUser: (data['is_user'] as int) == 1,
        timestamp: DateTime.fromMillisecondsSinceEpoch(data['timestamp'] as int),
      );
    }).toList();
  }

  /// Mobile implementation
  Future<List<ConversationMessage>> _loadMessagesMobile() async {
    final db = await database;
    if (db == null) return [];

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
    try {
      if (kIsWeb) {
        _webMessages.clear();
      } else {
        final db = await database;
        if (db != null) {
          await db.delete('conversations');
        }
      }
    } catch (e) {
      print('Database clear error: $e');
    }
  }

  /// Get count of messages in storage
  Future<int> getMessageCount() async {
    try {
      if (kIsWeb) {
        return _webMessages.length;
      } else {
        final db = await database;
        if (db == null) return 0;

        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM conversations',
        );
        return (result.first['count'] as int?) ?? 0;
      }
    } catch (e) {
      print('Database count error: $e');
      return 0;
    }
  }

  /// Delete messages older than specified days
  Future<void> deleteOldMessages(int daysToKeep) async {
    try {
      if (kIsWeb) {
        final cutoffTime = DateTime.now().subtract(Duration(days: daysToKeep));
        _webMessages.removeWhere((msg) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] as int);
          return timestamp.isBefore(cutoffTime);
        });
      } else {
        final db = await database;
        if (db == null) return;

        final cutoffTime = DateTime.now().subtract(Duration(days: daysToKeep));
        await db.delete(
          'conversations',
          where: 'timestamp < ?',
          whereArgs: [cutoffTime.millisecondsSinceEpoch],
        );
      }
    } catch (e) {
      print('Database cleanup error: $e');
    }
  }

  /// Close the database connection
  Future<void> close() async {
    try {
      if (!kIsWeb) {
        final db = _database;
        if (db != null) {
          await db.close();
          _database = null;
        }
      }
      // Web storage persists in memory until page reload
    } catch (e) {
      print('Database close error: $e');
      _database = null;
    }
  }

  /// Test storage connectivity
  Future<bool> testConnection() async {
    try {
      if (kIsWeb) {
        // Test in-memory storage
        return true;
      } else {
        final db = await database;
        if (db == null) return false;
        await db.rawQuery('SELECT 1');
        return true;
      }
    } catch (e) {
      print('Storage connection test failed: $e');
      return false;
    }
  }
}