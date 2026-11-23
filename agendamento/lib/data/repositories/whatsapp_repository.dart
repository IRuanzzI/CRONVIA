import 'dart:convert';

import '../api/api_client.dart';
import '../mock/mock_db.dart';
import '../models/empresa.dart';

/// Conexão de WhatsApp de uma empresa (instância na Evolution API).
///
/// [tenantId] só vale para o MASTER (gerencia a empresa de um cliente); o
/// ADMIN omite e gerencia a própria empresa.
abstract class WhatsappRepository {
  Future<WhatsappStatus> status({int? tenantId});
  Future<WhatsappQr> conectar({int? tenantId});
  Future<WhatsappStatus> desconectar({int? tenantId});
}

class ApiWhatsappRepository implements WhatsappRepository {
  ApiWhatsappRepository(this._api);

  final ApiClient _api;

  String _caminho(String base, int? tenantId) =>
      tenantId == null ? base : '$base?tenantId=$tenantId';

  @override
  Future<WhatsappStatus> status({int? tenantId}) async {
    final json = await _api.get(_caminho('/api/v1/whatsapp/status', tenantId));
    return WhatsappStatus.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<WhatsappQr> conectar({int? tenantId}) async {
    final json = await _api.post(_caminho('/api/v1/whatsapp/conectar', tenantId));
    return WhatsappQr.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<WhatsappStatus> desconectar({int? tenantId}) async {
    final json = await _api.delete(_caminho('/api/v1/whatsapp/desconectar', tenantId));
    return WhatsappStatus.fromJson(json as Map<String, dynamic>);
  }
}

/// Modo `USE_MOCK`: o "QR code" é uma imagem mínima e, depois de algumas
/// consultas de status, a conexão "abre" sozinha.
class MockWhatsappRepository implements WhatsappRepository {
  String _estado = 'inexistente';
  int _consultas = 0;

  // PNG 1x1 válido.
  static const _png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

  WhatsappStatus _status() => WhatsappStatus(
    instancia: 'tenant_demo',
    estado: _estado,
    conectado: _estado == 'open',
  );

  @override
  Future<WhatsappStatus> status({int? tenantId}) async {
    await latenciaMock();
    if (_estado == 'connecting' && ++_consultas >= 3) _estado = 'open';
    return _status();
  }

  @override
  Future<WhatsappQr> conectar({int? tenantId}) async {
    await latenciaMock();
    if (_estado == 'open') {
      return const WhatsappQr(estado: 'open', conectado: true);
    }
    _estado = 'connecting';
    _consultas = 0;
    return WhatsappQr(
      estado: 'qr',
      conectado: false,
      qr: base64Decode(_png),
    );
  }

  @override
  Future<WhatsappStatus> desconectar({int? tenantId}) async {
    await latenciaMock();
    _estado = 'close';
    return _status();
  }
}
