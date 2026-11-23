import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../data/models/empresa.dart';
import '../data/repositories/empresas_repository.dart';

/// Estado do painel do MASTER (lista e ações sobre as empresas).
class EmpresasController extends ChangeNotifier {
  EmpresasController(this._repo);

  final EmpresasRepository _repo;

  List<Empresa> _empresas = [];
  bool _carregando = false;
  String? _erro;

  List<Empresa> get empresas => _empresas;
  bool get carregando => _carregando;
  String? get erro => _erro;

  Empresa? porId(int? id) {
    if (id == null) return null;
    return _empresas.where((e) => e.id == id).firstOrNull;
  }

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _empresas = await _repo.listar();
    } catch (e) {
      debugPrint('Erro ao carregar empresas: $e');
      _erro = mensagemDeErro(e);
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  void limpar() {
    _empresas = [];
    _erro = null;
    notifyListeners();
  }

  Future<Empresa> criar(NovaEmpresa nova) async {
    final empresa = await _repo.criar(nova);
    _empresas = [..._empresas, empresa];
    notifyListeners();
    return empresa;
  }

  Future<void> atualizar(
    int id, {
    required String nomeFantasia,
    String? plano,
    DateTime? venceEm,
  }) async {
    final nova = await _repo.atualizar(
      id,
      nomeFantasia: nomeFantasia,
      plano: plano,
      venceEm: venceEm,
    );
    _trocar(nova);
  }

  Future<void> definirAtivo(int id, {required bool ativo}) async {
    _trocar(await _repo.definirAtivo(id, ativo: ativo));
  }

  /// A senha provisória só existe nesta resposta: mostre ao MASTER na hora.
  Future<SenhaTemporaria> redefinirSenhaAdmin(int id) =>
      _repo.redefinirSenhaAdmin(id);

  Future<List<AuditoriaItem>> auditoria(int id) => _repo.auditoria(id);

  void _trocar(Empresa nova) {
    _empresas = [for (final e in _empresas) e.id == nova.id ? nova : e];
    notifyListeners();
  }
}
