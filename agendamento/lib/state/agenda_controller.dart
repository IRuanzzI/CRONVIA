import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../core/utils/formatters.dart';
import '../data/models/agendamento.dart';
import '../data/models/cliente.dart';
import '../data/repositories/agendamento_repository.dart';

class AgendaController extends ChangeNotifier {
  AgendaController(this._repo);

  final AgendamentoRepository _repo;

  List<Agendamento> _agendamentos = [];
  bool _carregando = false;
  String? _erro;
  DateTime _dataSelecionada = soData(DateTime.now());

  List<Agendamento> get agendamentos => _agendamentos;
  bool get carregando => _carregando;
  String? get erro => _erro;
  DateTime get dataSelecionada => _dataSelecionada;

  void selecionarData(DateTime data) {
    _dataSelecionada = soData(data);
    notifyListeners();
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _agendamentos = await _repo.listar();
    } catch (e) {
      debugPrint('Erro ao carregar agenda: $e');
      _erro = mensagemDeErro(e);
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  void limpar() {
    _agendamentos = [];
    _erro = null;
    _dataSelecionada = soData(DateTime.now());
    notifyListeners();
  }

  List<Agendamento> doDia(DateTime dia) {
    final lista = _agendamentos.where((a) => mesmoDia(a.inicio, dia)).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    return lista;
  }

  int get totalHoje => doDia(DateTime.now()).where((a) => a.ativo).length;

  /// Próximos atendimentos de hoje que ainda não terminaram.
  List<Agendamento> proximosHoje({int limite = 3}) {
    final agora = DateTime.now();
    return doDia(
      agora,
    ).where((a) => a.ativo && a.fim.isAfter(agora)).take(limite).toList();
  }

  /// Atendimentos do cliente que já começaram, do mais recente ao mais antigo.
  List<Agendamento> historico(int clienteId) {
    final agora = DateTime.now();
    return _agendamentos
        .where((a) => a.cliente.id == clienteId && a.inicio.isBefore(agora))
        .toList()
      ..sort((a, b) => b.inicio.compareTo(a.inicio));
  }

  DateTime? ultimoAtendimento(int clienteId) =>
      historico(clienteId).where((a) => a.ativo).firstOrNull?.inicio;

  Future<Agendamento> criar({
    required Cliente cliente,
    required DateTime inicio,
    required int duracaoMin,
  }) async {
    final novo = await _repo.criar(
      cliente: cliente,
      inicio: inicio,
      fim: inicio.add(Duration(minutes: duracaoMin)),
    );
    _agendamentos = [..._agendamentos, novo];
    notifyListeners();
    return novo;
  }

  Future<void> definirStatus(int id, StatusAgendamento status) async {
    final atual = _agendamentos.where((a) => a.id == id).firstOrNull;
    if (atual == null) return;
    final atualizado = await _repo.atualizarStatus(atual, status);
    _agendamentos = [for (final a in _agendamentos) a.id == id ? atualizado : a];
    notifyListeners();
  }

  Future<void> excluir(int id) async {
    await _repo.excluir(id);
    _agendamentos = _agendamentos.where((a) => a.id != id).toList();
    notifyListeners();
  }
}
