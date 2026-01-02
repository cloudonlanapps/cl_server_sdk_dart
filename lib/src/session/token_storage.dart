import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;

import 'session_exceptions.dart';

/// Simple in-memory token storage with optional encryption
///
/// Stores and retrieves JWT tokens and optionally encrypted passwords
/// for token refresh scenarios. Uses in-memory storage (non-persistent).
///
/// For production Flutter apps, consider extending this class to use
/// `shared_preferences` or `flutter_secure_storage`.
class TokenStorage {
  /// Create a token storage instance
  TokenStorage() {
    _initializeEncryption();
  }
  // In-memory storage
  late final Map<String, String> _cache = <String, String>{};

  late final encrypt.Key _encryptionKey;
  late final encrypt.IV _iv;

  /// Initialize encryption key for password storage
  void _initializeEncryption() {
    try {
      // Generate or retrieve encryption key (device-specific)
      // For now, use a simple derived key from a salt
      final keyString = _generateEncryptionKey();
      _encryptionKey = encrypt.Key.fromUtf8(keyString);
      // Create a fixed IV based on a constant seed
      // (not random for reproducibility)
      _iv = encrypt.IV(Uint8List.fromList(List<int>.filled(16, 0)));
    } on Exception catch (e) {
      throw PasswordEncryptionException('Failed to initialize encryption: $e');
    }
  }

  /// Generate a consistent encryption key (in production, use device ID)
  String _generateEncryptionKey() {
    // Generate a 32-character key for 256-bit AES encryption
    // In production, derive from device ID or secure storage
    const key = 'cl_server_dart_secure_key_v1_32!';
    // Ensure key is exactly 32 characters (256 bits for AES)
    return key.length == 32 ? key : (key * 2).substring(0, 32);
  }

  static const String _usernameKey = 'cl_session_username';
  static const String _tokenKey = 'cl_session_token';
  static const String _encryptedPasswordKey = 'cl_session_enc_password';
  static const String _refreshTimeKey = 'cl_session_refresh_time';

  /// Check if a token is stored
  Future<bool> hasToken() async {
    return _cache.containsKey(_tokenKey);
  }

  /// Save token and username
  Future<void> saveToken(String username, String token) async {
    try {
      _cache[_usernameKey] = username;
      _cache[_tokenKey] = token;
    } on Exception catch (e) {
      throw TokenStorageException('Failed to save token: $e');
    }
  }

  /// Get stored token
  Future<String?> getToken() async {
    try {
      return _cache[_tokenKey];
    } on Exception catch (e) {
      throw TokenStorageException('Failed to retrieve token: $e');
    }
  }

  /// Get stored username
  Future<String?> getUsername() async {
    try {
      return _cache[_usernameKey];
    } on Exception catch (e) {
      throw TokenStorageException('Failed to retrieve username: $e');
    }
  }

  /// Get the time when token was last refreshed
  Future<DateTime?> getLastRefreshTime() async {
    try {
      final timestampStr = _cache[_refreshTimeKey];
      if (timestampStr == null) return null;
      final timestamp = int.tryParse(timestampStr);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } on Exception catch (e) {
      throw TokenStorageException('Failed to retrieve refresh time: $e');
    }
  }

  /// Update the last refresh time to now
  Future<void> updateRefreshTime() async {
    try {
      _cache[_refreshTimeKey] = DateTime.now().millisecondsSinceEpoch
          .toString();
    } on Exception catch (e) {
      throw TokenStorageException('Failed to update refresh time: $e');
    }
  }

  /// Update only the token (keeps username and refresh time)
  Future<void> updateToken(String newToken) async {
    try {
      _cache[_tokenKey] = newToken;
    } on Exception catch (e) {
      throw TokenStorageException('Failed to update token: $e');
    }
  }

  /// Save encrypted password for re-login strategy
  Future<void> saveEncryptedPassword(String username, String password) async {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      // Handle empty string as special case - encrypt adds a marker
      final passwordToEncrypt = password.isEmpty ? '___EMPTY___' : password;
      final encrypted = encrypter.encrypt(passwordToEncrypt, iv: _iv);
      // Store IV with cipher
      final encryptedString = '${encrypted.base64}:${_iv.base64}';
      _cache[_encryptedPasswordKey] = encryptedString;
    } on Exception catch (e) {
      throw PasswordEncryptionException('Failed to encrypt password: $e');
    }
  }

  /// Get decrypted password (for re-login strategy)
  Future<String?> getDecryptedPassword() async {
    try {
      final encryptedString = _cache[_encryptedPasswordKey];
      if (encryptedString == null) return null;

      // Extract cipher and IV
      final parts = encryptedString.split(':');
      if (parts.length != 2) return null;

      final cipherText = parts[0];
      final ivString = parts[1];

      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final decrypted = encrypter.decrypt64(
        cipherText,
        iv: encrypt.IV.fromBase64(ivString),
      );
      // Handle empty string special case
      return decrypted == '___EMPTY___' ? '' : decrypted;
    } on Exception catch (e) {
      throw PasswordEncryptionException('Failed to decrypt password: $e');
    }
  }

  /// Clear all stored session data
  Future<void> clearToken() async {
    try {
      _cache
        ..remove(_usernameKey)
        ..remove(_tokenKey)
        ..remove(_encryptedPasswordKey)
        ..remove(_refreshTimeKey);
    } on Exception catch (e) {
      throw TokenStorageException('Failed to clear token: $e');
    }
  }

  /// Clear stored password
  Future<void> clearPassword() async {
    try {
      _cache.remove(_encryptedPasswordKey);
    } on Exception catch (e) {
      throw TokenStorageException('Failed to clear password: $e');
    }
  }
}
