import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import '../data/models/notificacao.dart';
import '../data/repositories/notificacoes_repository.dart';

class NotificacoesController extends ChangeNotifier {
  NotificacoesController(this._repo);

  final NotificacoesRepository _repo;

  List<Notificacao> _notificacoes = [];
  bool _carregando = false;
  String? _erro;

  List<Notificacao> get notificacoes => _notificacoes;
  bool get carregando => _carregando;
  String? get erro => _erro;

  Future<void> carregar() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _notificacoes = await _repo.listar();
    } catch (e) {
      debugPrint('Erro ao carregar notificacoes: $e');
      _erro = mensagemDeErro(e);
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  void limpar() {
    _notificacoes = [];
    _erro = null;
    notifyListeners();
  }
}
