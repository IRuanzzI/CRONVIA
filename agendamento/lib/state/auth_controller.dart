import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/usuario.dart';
import '../data/repositories/auth_repository.dart';
import '../data/storage/session_store.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repo, this._store, {this.aoMudarToken, this.aoSair});

  final AuthRepository _repo;
  final SessionStore _store;

  /// Avisa o cliente HTTP quando o token muda.
  final void Function(String? token)? aoMudarToken;

  /// Chamado ao sair (para limpar os dados em memória).
  final VoidCallback? aoSair;

  Usuario? _usuario;
  String? _token;
  bool _notificacoes = true;
  String? _aviso;

  Usuario? get usuario => _usuario;
  bool get logado => _usuario != null;
  bool get notificacoesAtivas => _notificacoes;

  /// Senha provisória: o app só libera o resto depois da troca.
  bool get precisaTrocarSenha => _usuario?.precisaTrocarSenha ?? false;

  /// Mensagem para mostrar na tela de login (ex.: empresa suspensa). Some
  /// depois de lida.
  String? consumirAviso() {
    final a = _aviso;
    _aviso = null;
    return a;
  }

  /// Retoma a sessão salva (chamar antes de abrir o app).
  Future<void> restaurar() async {
    final sessao = await _store.ler();
    if (sessao == null) return;
    _usuario = sessao.usuario;
    _token = sessao.token;
    aoMudarToken?.call(sessao.token);
  }

  Future<void> login(String email, String senha) async {
    final sessao = await _repo.login(email, senha);
    aoMudarToken?.call(sessao.token);
    await _store.salvar(sessao);
    _usuario = sessao.usuario;
    _token = sessao.token;
    notifyListeners();
  }

  /// Troca a própria senha. Se era a provisória, libera o app.
  Future<void> alterarSenha({required String atual, required String nova}) async {
    await _repo.alterarSenha(atual: atual, nova: nova);
    final u = _usuario;
    final t = _token;
    if (u != null && t != null) {
      _usuario = u.copyWith(precisaTrocarSenha: false);
      await _store.salvar(Sessao(token: t, usuario: _usuario!));
    }
    notifyListeners();
  }

  /// A API recusou o acesso (empresa suspensa/vencida): encerra a sessão e
  /// guarda o motivo para a tela de login.
  void bloquearAcesso(String mensagem) {
    if (!logado) return;
    _aviso = mensagem;
    unawaited(sair());
  }

  Future<void> sair() async {
    _usuario = null;
    _token = null;
    aoMudarToken?.call(null);
    aoSair?.call();
    await _store.limpar();
    notifyListeners();
  }

  void definirNotificacoes(bool ativas) {
    _notificacoes = ativas;
    notifyListeners();
  }
}
