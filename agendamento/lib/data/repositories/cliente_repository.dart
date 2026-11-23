import '../../core/errors.dart';
import '../../core/utils/formatters.dart';
import '../api/api_client.dart';
import '../mock/mock_db.dart';
import '../models/cliente.dart';

abstract class ClienteRepository {
  Future<List<Cliente>> listar();
  Future<Cliente> criar({
    required String nome,
    required String telefone,
    String email = '',
  });
  Future<Cliente> atualizar(Cliente cliente);
  Future<void> excluir(int id);
}

class ApiClienteRepository implements ClienteRepository {
  ApiClienteRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Cliente>> listar() async {
    final json = await _api.get('/api/v1/clientes');
    return [
      for (final item in json as List) Cliente.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// A empresa e a data de cadastro são definidas pela API.
  @override
  Future<Cliente> criar({
    required String nome,
    required String telefone,
    String email = '',
  }) async {
    final json = await _api.post(
      '/api/v1/clientes/create',
      corpo: {
        'nome': nome,
        'telefone': telefoneParaApi(telefone),
        if (email.isNotEmpty) 'email': email,
      },
    );
    return Cliente.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Cliente> atualizar(Cliente cliente) async {
    final json = await _api.put(
      '/api/v1/clientes/edit/${cliente.id}',
      // E-mail vazio limpa o campo no servidor.
      corpo: {
        'nome': cliente.nome,
        'telefone': telefoneParaApi(cliente.telefone),
        'email': cliente.email,
      },
    );
    return Cliente.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> excluir(int id) async {
    try {
      await _api.delete('/api/v1/clientes/delete/$id');
    } on ApiException catch (e) {
      // 409 já traz a mensagem do servidor; 500 é o comportamento antigo.
      if (e.statusCode >= 500) {
        throw const AppException(
          'Não foi possível excluir. O cliente pode ter agendamentos.',
        );
      }
      rethrow;
    }
  }
}

class MockClienteRepository implements ClienteRepository {
  MockClienteRepository(this._db);

  final MockDb _db;

  @override
  Future<List<Cliente>> listar() async {
    await latenciaMock();
    return List.of(_db.clientes);
  }

  @override
  Future<Cliente> criar({
    required String nome,
    required String telefone,
    String email = '',
  }) async {
    await latenciaMock();
    final cliente = Cliente(
      id: _db.proximoId(),
      nome: nome,
      telefone: telefoneParaApi(telefone),
      email: email,
      desde: DateTime.now(),
    );
    _db.clientes.add(cliente);
    return cliente;
  }

  @override
  Future<Cliente> atualizar(Cliente cliente) async {
    await latenciaMock();
    final i = _db.clientes.indexWhere((c) => c.id == cliente.id);
    if (i < 0) throw const AppException('Cliente não encontrado.');
    final salvo = cliente.copyWith(telefone: telefoneParaApi(cliente.telefone));
    _db.clientes[i] = salvo;
    for (var j = 0; j < _db.agendamentos.length; j++) {
      if (_db.agendamentos[j].cliente.id == salvo.id) {
        _db.agendamentos[j] = _db.agendamentos[j].copyWith(cliente: salvo);
      }
    }
    return salvo;
  }

  @override
  Future<void> excluir(int id) async {
    await latenciaMock();
    if (_db.agendamentos.any((a) => a.cliente.id == id)) {
      throw const AppException(
        'Não foi possível excluir. O cliente pode ter agendamentos.',
      );
    }
    _db.clientes.removeWhere((c) => c.id == id);
  }
}
