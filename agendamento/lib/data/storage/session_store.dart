import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/usuario.dart';

/// Guarda a sessão para o usuário não precisar entrar toda vez.
abstract class SessionStore {
  Future<Sessao?> ler();
  Future<void> salvar(Sessao sessao);
  Future<void> limpar();
}

class SecureSessionStore implements SessionStore {
  SecureSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _chave = 'sessao_v1';

  @override
  Future<Sessao?> ler() async {
    try {
      final bruto = await _storage.read(key: _chave);
      if (bruto == null) return null;
      final json = jsonDecode(bruto) as Map<String, dynamic>;
      return Sessao(
        token: json['token'] as String,
        usuario: Usuario.fromJson(json['usuario'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('Não foi possível ler a sessão salva: $e');
      return null;
    }
  }

  @override
  Future<void> salvar(Sessao sessao) async {
    try {
      await _storage.write(
        key: _chave,
        value: jsonEncode({
          'token': sessao.token,
          'usuario': sessao.usuario.toJson(),
        }),
      );
    } catch (e) {
      debugPrint('Não foi possível salvar a sessão: $e');
    }
  }

  @override
  Future<void> limpar() async {
    try {
      await _storage.delete(key: _chave);
    } catch (e) {
      debugPrint('Não foi possível limpar a sessão: $e');
    }
  }
}

class MemorySessionStore implements SessionStore {
  Sessao? _sessao;

  @override
  Future<Sessao?> ler() async => _sessao;

  @override
  Future<void> salvar(Sessao sessao) async => _sessao = sessao;

  @override
  Future<void> limpar() async => _sessao = null;
}
