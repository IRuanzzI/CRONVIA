import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../data/models/consultorio.dart';
import '../data/models/servico.dart';
import '../data/repositories/consultorio_repository.dart';

class ConsultorioController extends ChangeNotifier {
  ConsultorioController(this._repo);

  final ConsultorioRepository _repo;

  Consultorio _consultorio = const Consultorio(
    nome: '',
    endereco: '',
    horarios: [],
  );
  List<Servico> _servicos = [];
  String? _erro;

  Consultorio get consultorio => _consultorio;
  List<Servico> get servicos => _servicos;
  String? get erro => _erro;

  Future<void> carregar() async {
    _erro = null;
    try {
      _consultorio = await _repo.obter();
      _servicos = await _repo.listarServicos();
    } catch (e) {
      debugPrint('Erro ao carregar consultório: $e');
      _erro = mensagemDeErro(e);
    }
    notifyListeners();
  }

  void limpar() {
    _consultorio = const Consultorio(nome: '', endereco: '', horarios: []);
    _servicos = [];
    _erro = null;
    notifyListeners();
  }

  Future<void> atualizarEndereco(String endereco) async {
    _consultorio = await _repo.salvar(_consultorio.copyWith(endereco: endereco));
    notifyListeners();
  }

  Future<void> atualizarHorario(int indice, int abreMin, int fechaMin) async {
    final horarios = [..._consultorio.horarios];
    horarios[indice] = horarios[indice].copyWith(
      abreMin: abreMin,
      fechaMin: fechaMin,
    );
    _consultorio = await _repo.salvar(_consultorio.copyWith(horarios: horarios));
    notifyListeners();
  }

  Future<void> salvarServico(Servico servico) async {
    final salvo = await _repo.salvarServico(servico);
    _servicos = servico.id == 0
        ? [..._servicos, salvo]
        : [for (final s in _servicos) s.id == salvo.id ? salvo : s];
    notifyListeners();
  }

  Future<void> excluirServico(int id) async {
    await _repo.excluirServico(id);
    _servicos = _servicos.where((s) => s.id != id).toList();
    notifyListeners();
  }
}
