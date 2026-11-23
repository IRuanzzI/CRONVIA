import '../../core/errors.dart';
import '../../core/utils/formatters.dart';
import '../api/api_client.dart';
import '../mock/mock_db.dart';
import '../models/agendamento.dart';
import '../models/cliente.dart';

abstract class AgendamentoRepository {
  Future<List<Agendamento>> listar();
  Future<Agendamento> criar({
    required Cliente cliente,
    required DateTime inicio,
    required DateTime fim,
  });
  Future<Agendamento> atualizarStatus(Agendamento agendamento, StatusAgendamento status);
  Future<void> excluir(int id);
}

/// A API define empresa, usuário, status inicial (PENDENTE) e lembrete ao
/// criar; o app só informa cliente, início e fim.
class ApiAgendamentoRepository implements AgendamentoRepository {
  ApiAgendamentoRepository(this._api);

  final ApiClient _api;

  Map<String, dynamic> _corpo({
    required int clienteId,
    required DateTime inicio,
    required DateTime fim,
    StatusAgendamento? status,
  }) => {
    'cliente': {'id': clienteId},
    'data_hora_inicio': paraIsoApi(inicio),
    'data_hora_final': paraIsoApi(fim),
    if (status != null) 'status': status.api,
  };

  @override
  Future<List<Agendamento>> listar() async {
    final json = await _api.get('/api/v1/agendamentos');
    final lista = <Agendamento>[];
    for (final item in json as List) {
      try {
        lista.add(Agendamento.fromJson(item as Map<String, dynamic>));
      } catch (_) {
        // Um registro malformado não deve derrubar a agenda inteira.
      }
    }
    return lista;
  }

  @override
  Future<Agendamento> criar({
    required Cliente cliente,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final json = await _api.post(
      '/api/v1/agendamentos/create',
      corpo: _corpo(clienteId: cliente.id, inicio: inicio, fim: fim),
    );
    return Agendamento.fromJson(json as Map<String, dynamic>);
  }

  /// O PUT atualiza só o que for enviado; aqui mudamos apenas o status.
  @override
  Future<Agendamento> atualizarStatus(
    Agendamento agendamento,
    StatusAgendamento status,
  ) async {
    final json = await _api.put(
      '/api/v1/agendamentos/edit/${agendamento.id}',
      corpo: _corpo(
        clienteId: agendamento.cliente.id,
        inicio: agendamento.inicio,
        fim: agendamento.fim,
        status: status,
      ),
    );
    return Agendamento.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> excluir(int id) => _api.delete('/api/v1/agendamentos/delete/$id');
}

class MockAgendamentoRepository implements AgendamentoRepository {
  MockAgendamentoRepository(this._db);

  final MockDb _db;

  @override
  Future<List<Agendamento>> listar() async {
    await latenciaMock();
    return List.of(_db.agendamentos);
  }

  @override
  Future<Agendamento> criar({
    required Cliente cliente,
    required DateTime inicio,
    required DateTime fim,
  }) async {
    await latenciaMock();
    final novo = Agendamento(
      id: _db.proximoId(),
      cliente: cliente,
      inicio: inicio,
      fim: fim,
      profissional: _db.nomeUsuario,
      usuarioId: 1,
    );
    _db.agendamentos.add(novo);
    return novo;
  }

  @override
  Future<Agendamento> atualizarStatus(
    Agendamento agendamento,
    StatusAgendamento status,
  ) async {
    await latenciaMock();
    final i = _db.agendamentos.indexWhere((a) => a.id == agendamento.id);
    if (i < 0) throw const AppException('Agendamento não encontrado.');
    _db.agendamentos[i] = _db.agendamentos[i].copyWith(status: status);
    return _db.agendamentos[i];
  }

  @override
  Future<void> excluir(int id) async {
    await latenciaMock();
    _db.agendamentos.removeWhere((a) => a.id == id);
  }
}
