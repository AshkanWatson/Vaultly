import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/credential_model.dart';
import '../../utils/constants.dart';

class VaultRepository {
  static Database? _db;
  enc.Key? _masterKey;
  enc.IV? _iv;

  // --- Security ---

  void deriveKey(String masterPassword) {
    var bytes = utf8.encode(masterPassword);
    var keyDigest = sha256.convert(bytes);
    _masterKey = enc.Key.fromLength(32)..bytes.setAll(0, keyDigest.bytes);
    var ivDigest = sha256.convert(keyDigest.bytes);
    _iv = enc.IV(Uint8List.fromList(ivDigest.bytes.sublist(0, 16)));
  }

  void lock() {
    _masterKey = null;
    _iv = null;
  }

  bool get isUnlocked => _masterKey != null;

  String _encrypt(String plainText) {
    if (_masterKey == null) throw Exception("Vault locked");
    final encrypter =
        enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.cbc));
    return encrypter.encrypt(plainText, iv: _iv).base64;
  }

  String _decrypt(String cipherText) {
    if (_masterKey == null) throw Exception("Vault locked");
    try {
      final encrypter =
          enc.Encrypter(enc.AES(_masterKey!, mode: enc.AESMode.cbc));
      return encrypter.decrypt(enc.Encrypted.fromBase64(cipherText), iv: _iv);
    } catch (e) {
      throw Exception("Decryption Error");
    }
  }

  // --- Database ---

  Future<void> initDB() async {
    final databasesPath = await getDatabasesPath();
    String path = join(databasesPath, kDatabaseName);

    _db = await openDatabase(path, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE $kTableName (
          id TEXT PRIMARY KEY,
          title TEXT,
          username TEXT,
          password TEXT,
          updated_at INTEGER,
          is_deleted INTEGER
        )
      ''');
    });
  }

  Future<List<Credential>> getAllCredentials() async {
    if (_db == null) await initDB();
    final List<Map<String, dynamic>> maps = await _db!.query(
      kTableName,
      where: 'is_deleted = 0',
    );

    List<Credential> results = [];
    for (var e in maps) {
      try {
        results.add(Credential(
          id: e['id'],
          title: _decrypt(e['title']),
          username: _decrypt(e['username']),
          password: _decrypt(e['password']),
          updatedAt: e['updated_at'],
        ));
      } catch (error) {
        print("Skipping unreadable item: ${e['id']}");
      }
    }
    return results;
  }

  Future<void> saveCredential(
      String? id, String title, String user, String pass) async {
    if (_db == null) await initDB();

    final newId = id ?? const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final data = {
      'id': newId,
      'title': _encrypt(title),
      'username': _encrypt(user),
      'password': _encrypt(pass),
      'updated_at': now,
      'is_deleted': 0
    };

    await _db!
        .insert(kTableName, data, conflictAlgorithm: ConflictAlgorithm.replace);
    syncData();
  }

  Future<void> deleteCredential(String id) async {
    if (_db == null) await initDB();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db!.update(kTableName, {'is_deleted': 1, 'updated_at': now},
        where: 'id = ?', whereArgs: [id]);
    syncData();
  }

  // --- Sync ---

  Future<void> syncData() async {
    try {
      if (Supabase.instance.client == null) return;
    } catch (e) {
      return;
    }

    final supabase = Supabase.instance.client;
    if (_db == null) await initDB();

    try {
      final localData = await _db!.query(kTableName);
      if (localData.isNotEmpty) {
        await supabase.from('user_credentials').upsert(localData);
      }

      final response = await supabase.from('user_credentials').select();
      final List<dynamic> remoteData = response as List<dynamic>;

      for (var remoteItem in remoteData) {
        final localItem = await _db!
            .query(kTableName, where: 'id = ?', whereArgs: [remoteItem['id']]);
        bool shouldUpdate = false;

        if (localItem.isEmpty) {
          shouldUpdate = true;
        } else {
          int localTime = localItem.first['updated_at'] as int;
          int remoteTime = remoteItem['updated_at'] as int;
          if (remoteTime > localTime) shouldUpdate = true;
        }

        if (shouldUpdate) {
          await _db!.insert(kTableName, remoteItem,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    } catch (e) {
      print("Sync Failed: $e");
    }
  }

  // --- Import/Export ---

  Future<String> exportVaultToString(String backupPassword) async {
    List<Credential> allCreds = await getAllCredentials();

    List<Map<String, dynamic>> plainList = allCreds
        .map((c) => {
              'title': c.title,
              'username': c.username,
              'password': c.password,
              'updated_at': c.updatedAt,
            })
        .toList();

    String jsonString = jsonEncode(plainList);
    final key = enc.Key.fromUtf8(padString(backupPassword, 32));
    final iv = enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(jsonString, iv: iv);
    return "${iv.base64}:${encrypted.base64}";
  }

  Future<void> importVaultFromString(
      String fileContent, String backupPassword) async {
    try {
      final cleanContent = fileContent.trim();
      if (cleanContent.isEmpty) throw Exception("File is empty (0 bytes).");

      final parts = cleanContent.split(':');
      if (parts.length != 2) throw Exception("Invalid File Format.");

      final iv = enc.IV.fromBase64(parts[0]);
      final cipherText = parts[1];
      final key = enc.Key.fromUtf8(padString(backupPassword, 32));
      final encrypter = enc.Encrypter(enc.AES(key));

      final decryptedString =
          encrypter.decrypt(enc.Encrypted.fromBase64(cipherText), iv: iv);
      final List<dynamic> jsonList = jsonDecode(decryptedString);

      for (var item in jsonList) {
        await saveCredential(
            null, item['title'], item['username'], item['password']);
      }
    } catch (e) {
      if (e.toString().contains("File is empty")) rethrow;
      if (e.toString().contains("Invalid File Format")) rethrow;
      throw Exception("Wrong Password or Corrupted File.");
    }
  }

  // --- Utils ---

  String padString(String str, int length) {
    if (str.length >= length) return str.substring(0, length);
    return str.padRight(length, '#');
  }

  static String generatePassword({int length = 16, bool useSpecial = true}) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const special = '@#%^*&!';
    final rnd = Random.secure();
    String result = '';
    if (useSpecial) result += special[rnd.nextInt(special.length)];
    final allChars = useSpecial ? chars + special : chars;
    while (result.length < length) {
      result += allChars[rnd.nextInt(allChars.length)];
    }
    List<String> list = result.split('')..shuffle(rnd);
    return list.join('');
  }
}
