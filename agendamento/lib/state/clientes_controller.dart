import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../data/models/cliente.dart';
import '../data/repositories/cliente_repository.dart';

class ClientesController extends ChangeNotifier {
  ClientesController(this._repo);

  final ClienteRepository _repo;

  List<Cliente> _clientes = [];
  bool _carregando = false;
  String? _erro;

  List<Cliente> get clientes => _clientes;
  bool get carregando => _carregando;

  /// Mensagem do último erro ao carregar (null se deu certo).
  String? get erro => _erro;

  Cliente? porId(int? id) {
    if (id == null) return null;
    return _clientes.where((c) => c.id == id).firstOrNull;
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _clientes = await _repo.listar();
    } catch (e) {
      debugPrint('Erro ao carregar clientes: $e');
      _erro = mensagemDeErro(e);
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  void limpar() {
    _clientes = [];
    _erro = null;
    notifyListeners();
  }

  Future<Cliente> criar({
    required String nome,
    required String telefone,
    String email = '',
  }) async {
    final cliente = await _repo.criar(
      nome: nome,
      telefone: telefone,
      email: email,
    );
    _clientes = [..._clientes, cliente];
    notifyListeners();
    return cliente;
  }

  Future<void> atualizar(Cliente cliente) async {
    final salvo = await _repo.atualizar(cliente);
    _clientes = [for (final c in _clientes) c.id == salvo.id ? salvo : c];
    notifyListeners();
  }

  Future<void> excluir(int id) async {
    await _repo.excluir(id);
    _clientes = _clientes.where((c) => c.id != id).toList();
    notifyListeners();
  }
}
