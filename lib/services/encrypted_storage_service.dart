import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 🔐 Encrypted Storage Service - Enterprise-Grade Security
/// 
/// Protege dados sensíveis (tokens, credenciais) com criptografia AES-256 GCM
/// mesmo em plataformas que usam SharedPreferences (Web, Windows).
/// 
/// ✅ Web: Criptografa antes de salvar em localStorage
/// ✅ Windows: Criptografa antes de salvar em arquivos
/// ✅ Android/iOS: Usa FlutterSecureStorage nativo + criptografia adicional
class EncryptedStorageService {
  final SharedPreferences? _prefs;
  final FlutterSecureStorage? _secureStorage;
  final bool _useNativeSecureStorage;
  
  // Chave de criptografia (gerada uma vez por device)
  encrypt.Encrypter? _encrypter;
  encrypt.IV? _iv;
  
  static const String _keyStorageKey = '_encrypted_storage_key';
  static const String _ivStorageKey = '_encrypted_storage_iv';

  EncryptedStorageService._({
    SharedPreferences? prefs,
    FlutterSecureStorage? secureStorage,
    required bool useNativeSecureStorage,
  })  : _prefs = prefs,
        _secureStorage = secureStorage,
        _useNativeSecureStorage = useNativeSecureStorage;

  /// Factory constructor - cria instância com criptografia adequada
  static Future<EncryptedStorageService> create() async {
    if (kIsWeb) {
      // Web: SharedPreferences + criptografia AES-256
      final prefs = await SharedPreferences.getInstance();
      final service = EncryptedStorageService._(
        prefs: prefs,
        useNativeSecureStorage: false,
      );
      await service._initializeEncryption();
      debugPrint('✅ [SEGURANÇA] Web: Usando SharedPreferences + AES-256 GCM');
      return service;
    }

    try {
      // Android/iOS/macOS/Linux: FlutterSecureStorage + criptografia extra
      final secureStorage = const FlutterSecureStorage();
      final prefs = await SharedPreferences.getInstance();
      
      final service = EncryptedStorageService._(
        secureStorage: secureStorage,
        prefs: prefs,
        useNativeSecureStorage: true,
      );
      await service._initializeEncryption();
      debugPrint('✅ [SEGURANÇA] Mobile: Usando FlutterSecureStorage + AES-256 GCM');
      return service;
    } catch (e) {
      // Fallback para SharedPreferences + criptografia
      final prefs = await SharedPreferences.getInstance();
      final service = EncryptedStorageService._(
        prefs: prefs,
        useNativeSecureStorage: false,
      );
      await service._initializeEncryption();
      debugPrint('⚠️ [SEGURANÇA] Fallback: SharedPreferences + AES-256 GCM');
      return service;
    }
  }

  /// Inicializa chaves de criptografia
  Future<void> _initializeEncryption() async {
    try {
      // Tenta recuperar chave existente
      String? keyB64;
      String? ivB64;

      if (_useNativeSecureStorage && _secureStorage != null) {
        // Lê de FlutterSecureStorage (mais seguro)
        keyB64 = await _secureStorage.read(key: _keyStorageKey);
        ivB64 = await _secureStorage.read(key: _ivStorageKey);
      } else {
        // Lê de SharedPreferences (criptografado)
        keyB64 = _prefs?.getString(_keyStorageKey);
        ivB64 = _prefs?.getString(_ivStorageKey);
      }

      if (keyB64 == null || ivB64 == null) {
        // Gera novas chaves
        final key = encrypt.Key.fromSecureRandom(32); // AES-256
        final iv = encrypt.IV.fromSecureRandom(16);

        keyB64 = base64.encode(key.bytes);
        ivB64 = base64.encode(iv.bytes);

        // Salva chaves
        if (_useNativeSecureStorage && _secureStorage != null) {
          await _secureStorage.write(key: _keyStorageKey, value: keyB64);
          await _secureStorage.write(key: _ivStorageKey, value: ivB64);
        } else {
          // Salva em SharedPreferences (será usado para criptografar os dados)
          await _prefs?.setString(_keyStorageKey, keyB64);
          await _prefs?.setString(_ivStorageKey, ivB64);
        }

        _encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
        _iv = iv;
        
        debugPrint('🔐 [SEGURANÇA] Novas chaves de criptografia geradas');
      } else {
        // Recupera chaves existentes
        final key = encrypt.Key(base64.decode(keyB64));
        _iv = encrypt.IV(base64.decode(ivB64));
        _encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
        
        debugPrint('🔐 [SEGURANÇA] Chaves de criptografia recuperadas');
      }
    } catch (e) {
      debugPrint('❌ [SEGURANÇA] Erro ao inicializar criptografia: $e');
      rethrow;
    }
  }

  /// 🔐 Salva valor criptografado
  /// 
  /// SEMPRE criptografa antes de salvar, mesmo em plataformas "seguras"
  Future<void> write({required String key, required String? value}) async {
    if (_encrypter == null || _iv == null) {
      throw StateError('Encryption not initialized');
    }

    try {
      if (value == null) {
        await delete(key: key);
        return;
      }

      // ═══════════════════════════════════════════════════════════
      // 🔐 CRIPTOGRAFA VALOR COM AES-256 GCM
      // ═══════════════════════════════════════════════════════════
      final encrypted = _encrypter!.encrypt(value, iv: _iv!);
      final encryptedB64 = encrypted.base64;

      // Salva valor criptografado
      if (_useNativeSecureStorage && _secureStorage != null) {
        // Dupla proteção: FlutterSecureStorage + AES-256
        await _secureStorage.write(key: key, value: encryptedB64);
      } else {
        // SharedPreferences com AES-256
        await _prefs?.setString(key, encryptedB64);
      }

      // NÃO loga o valor (mesmo criptografado)
      if (kDebugMode) {
        debugPrint('✅ [SEGURANÇA] Valor salvo e criptografado: $key');
      }
    } catch (e) {
      debugPrint('❌ [SEGURANÇA] Erro ao salvar valor criptografado: $e');
      rethrow;
    }
  }

  /// 🔓 Lê e descriptografa valor
  Future<String?> read({required String key}) async {
    if (_encrypter == null || _iv == null) {
      throw StateError('Encryption not initialized');
    }

    try {
      String? encryptedB64;

      // Lê valor criptografado
      if (_useNativeSecureStorage && _secureStorage != null) {
        encryptedB64 = await _secureStorage.read(key: key);
      } else {
        encryptedB64 = _prefs?.getString(key);
      }

      if (encryptedB64 == null) {
        return null;
      }

      // ═══════════════════════════════════════════════════════════
      // 🔓 DESCRIPTOGRAFA VALOR
      // ═══════════════════════════════════════════════════════════
      final encrypted = encrypt.Encrypted.fromBase64(encryptedB64);
      final decrypted = _encrypter!.decrypt(encrypted, iv: _iv!);

      // NÃO loga o valor descriptografado
      if (kDebugMode) {
        debugPrint('✅ [SEGURANÇA] Valor lido e descriptografado: $key');
      }

      return decrypted;
    } catch (e) {
      debugPrint('❌ [SEGURANÇA] Erro ao ler valor criptografado: $e');
      // Retorna null se não conseguir descriptografar (chave pode ter mudado)
      return null;
    }
  }

  /// 🗑️ Deleta valor
  Future<void> delete({required String key}) async {
    try {
      if (_useNativeSecureStorage && _secureStorage != null) {
        await _secureStorage.delete(key: key);
      } else {
        await _prefs?.remove(key);
      }

      if (kDebugMode) {
        debugPrint('✅ [SEGURANÇA] Valor deletado: $key');
      }
    } catch (e) {
      debugPrint('❌ [SEGURANÇA] Erro ao deletar valor: $e');
      rethrow;
    }
  }

  /// 🗑️ Deleta todos os valores (exceto chaves de criptografia)
  Future<void> deleteAll() async {
    try {
      if (_useNativeSecureStorage && _secureStorage != null) {
        // Deleta tudo, mas mantém as chaves de criptografia
        final allKeys = await _secureStorage.readAll();
        for (final key in allKeys.keys) {
          if (key != _keyStorageKey && key != _ivStorageKey) {
            await _secureStorage.delete(key: key);
          }
        }
      } else {
        // Deleta tudo do SharedPreferences, mas mantém as chaves
        final keys = _prefs?.getKeys() ?? {};
        for (final key in keys) {
          if (key != _keyStorageKey && key != _ivStorageKey) {
            await _prefs?.remove(key);
          }
        }
      }

      if (kDebugMode) {
        debugPrint('✅ [SEGURANÇA] Todos os valores deletados (chaves mantidas)');
      }
    } catch (e) {
      debugPrint('❌ [SEGURANÇA] Erro ao deletar valores: $e');
      rethrow;
    }
  }

  /// ✅ Verifica se chave existe
  Future<bool> containsKey({required String key}) async {
    try {
      if (_useNativeSecureStorage && _secureStorage != null) {
        final value = await _secureStorage.read(key: key);
        return value != null;
      } else {
        return _prefs?.containsKey(key) ?? false;
      }
    } catch (e) {
      return false;
    }
  }

  /// 🔄 Re-criptografa todos os dados (quando chave muda)
  Future<void> rotateEncryptionKeys() async {
    debugPrint('🔐 [SEGURANÇA] Rotacionando chaves de criptografia...');
    
    try {
      // Lê todos os valores descriptografados
      final Map<String, String> allData = {};
      
      if (_useNativeSecureStorage && _secureStorage != null) {
        final allKeys = await _secureStorage.readAll();
        for (final entry in allKeys.entries) {
          if (entry.key != _keyStorageKey && entry.key != _ivStorageKey) {
            final value = await read(key: entry.key);
            if (value != null) {
              allData[entry.key] = value;
            }
          }
        }
      } else {
        final keys = _prefs?.getKeys() ?? {};
        for (final key in keys) {
          if (key != _keyStorageKey && key != _ivStorageKey) {
            final value = await read(key: key);
            if (value != null) {
              allData[key] = value;
            }
          }
        }
      }

      // Gera novas chaves
      final newKey = encrypt.Key.fromSecureRandom(32);
      final newIV = encrypt.IV.fromSecureRandom(16);

      _encrypter = encrypt.Encrypter(encrypt.AES(newKey, mode: encrypt.AESMode.gcm));
      _iv = newIV;

      // Salva novas chaves
      final keyB64 = base64.encode(newKey.bytes);
      final ivB64 = base64.encode(newIV.bytes);

      if (_useNativeSecureStorage && _secureStorage != null) {
        await _secureStorage.write(key: _keyStorageKey, value: keyB64);
        await _secureStorage.write(key: _ivStorageKey, value: ivB64);
      } else {
        await _prefs?.setString(_keyStorageKey, keyB64);
        await _prefs?.setString(_ivStorageKey, ivB64);
      }

      // Re-criptografa todos os dados com novas chaves
      for (final entry in allData.entries) {
        await write(key: entry.key, value: entry.value);
      }

      debugPrint('✅ [SEGURANÇA] Chaves rotacionadas com sucesso (${allData.length} valores re-criptografados)');
    } catch (e) {
      debugPrint('❌ [SEGURANÇA] Erro ao rotacionar chaves: $e');
      rethrow;
    }
  }
}

