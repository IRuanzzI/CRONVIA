import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/errors.dart';

/// Cliente HTTP da API (JSON + token JWT no cabeçalho Authorization).
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  /// Definido ao entrar e limpo ao sair.
  String? token;

  /// Chamado quando a API informa que a empresa foi suspensa ou a assinatura
  /// venceu (HTTP 403), para o app encerrar a sessão e avisar.
  void Function(String mensagem)? aoBloquearAcesso;

  Future<dynamic> get(String caminho, {Map<String, String>? query}) =>
      _enviar('GET', caminho, query: query);

  Future<dynamic> post(String caminho, {Object? corpo}) =>
      _enviar('POST', caminho, corpo: corpo);

  Future<dynamic> put(String caminho, {Object? corpo}) =>
      _enviar('PUT', caminho, corpo: corpo);

  Future<dynamic> delete(String caminho) => _enviar('DELETE', caminho);

  Future<dynamic> _enviar(
    String metodo,
    String caminho, {
    Map<String, String>? query,
    Object? corpo,
  }) async {
    final uri = Uri.parse('$baseUrl$caminho').replace(queryParameters: query);
    final request = http.Request(metodo, uri)
      ..headers['Accept'] = 'application/json';
    final t = token;
    if (t != null) request.headers['Authorization'] = 'Bearer $t';
    if (corpo != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(corpo);
    }

    final http.Response resposta;
    try {
      resposta = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      );
    } on TimeoutException {
      throw const AppException(
        'O servidor demorou para responder. Tente novamente.',
      );
    } on http.ClientException catch (e) {
      debugPrint('Falha de conexão com $uri: $e');
      throw const AppException(
        'Não foi possível conectar ao servidor. Verifique a conexão.',
      );
    }

    final texto = utf8.decode(resposta.bodyBytes, allowMalformed: true);
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) {
      if (texto.trim().isEmpty) return null;
      try {
        return jsonDecode(texto);
      } on FormatException {
        // Alguns endpoints devolvem texto puro (ex.: /tenants/me).
        return texto;
      }
    }

    debugPrint('API $metodo $caminho -> ${resposta.statusCode}: $texto');
    final mensagem = _mensagemDoErro(resposta.statusCode, texto);
    // Só com sessão aberta (no login, o AuthRepository já mostra a mensagem).
    if (resposta.statusCode == 403 &&
        token != null &&
        RegExp(r'suspensa|vencida', caseSensitive: false).hasMatch(mensagem)) {
      aoBloquearAcesso?.call(mensagem);
    }
    throw ApiException(mensagem, statusCode: resposta.statusCode);
  }

  static String _mensagemDoErro(int status, String corpo) {
    final doServidor = _mensagemDoCorpo(corpo);
    if (doServidor != null) return doServidor;
    return switch (status) {
      400 || 422 => 'Os dados enviados são inválidos.',
      401 => 'Sessão inválida. Entre novamente.',
      403 => 'Você não tem permissão para esta ação.',
      404 => 'Não encontrado.',
      >= 500 => 'O servidor encontrou um erro. Tente novamente.',
      _ => 'Não foi possível concluir a ação.',
    };
  }

  /// Usa o campo `message` do erro quando a API o envia (o Spring omite por
  /// padrão, e o texto genérico "Internal Server Error" não ajuda ninguém).
  static String? _mensagemDoCorpo(String corpo) {
    try {
      final json = jsonDecode(corpo);
      if (json is Map && json['message'] is String) {
        final m = (json['message'] as String).trim();
        if (m.isNotEmpty) return m;
      }
    } on FormatException {
      // corpo não é JSON
    }
    return null;
  }

  void close() => _client.close();
}
