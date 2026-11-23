import '../api/api_client.dart';
import '../mock/mock_db.dart';
import '../models/notificacao.dart';

abstract class NotificacoesRepository {
  Future<List<Notificacao>> listar();
}

class ApiNotificacoesRepository implements NotificacoesRepository {
  ApiNotificacoesRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Notificacao>> listar() async {
    final json = await _api.get('/api/v1/notificacoes');
    final lista = <Notificacao>[];
    for (final item in _extrairItens(json)) {
      if (item is! Map) continue;
      final mapa = item.map(
        (chave, valor) => MapEntry(chave.toString(), valor),
      );
      try {
        lista.add(Notificacao.fromJson(mapa));
      } catch (_) {
        // Um registro malformado nao deve derrubar a lista inteira.
      }
    }
    return lista;
  }

  Iterable<dynamic> _extrairItens(dynamic json) {
    if (json is List) return json;

    if (json is Map) {
      for (final chave in const [
        'data',
        'content',
        'items',
        'notificacoes',
        'notifications',
        'records',
        'list',
      ]) {
        final valor = json[chave];
        if (valor is List) return valor;
      }

      for (final valor in json.values) {
        if (valor is List) return valor;
      }

      if (json.containsKey('id') ||
          json.containsKey('titulo') ||
          json.containsKey('mensagem') ||
          json.containsKey('title') ||
          json.containsKey('message')) {
        return [json];
      }
    }

    return const [];
  }
}

class MockNotificacoesRepository implements NotificacoesRepository {
  MockNotificacoesRepository(this._db);

  final MockDb _db;

  @override
  Future<List<Notificacao>> listar() async {
    await latenciaMock();
    return List.of(_db.notificacoes);
  }
}
