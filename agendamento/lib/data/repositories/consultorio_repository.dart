import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errors.dart';
import '../mock/mock_db.dart';
import '../models/consultorio.dart';
import '../models/servico.dart';
import '../models/usuario.dart';

abstract class ConsultorioRepository {
  Future<Consultorio> obter();
  Future<Consultorio> salvar(Consultorio consultorio);
  Future<List<Servico>> listarServicos();

  /// `servico.id == 0` cria um novo; caso contrário, atualiza.
  Future<Servico> salvarServico(Servico servico);
  Future<void> excluirServico(int id);
}

/// Guarda endereço, horários e serviços no aparelho (por empresa), enquanto a
/// API não tem onde guardá-los. O nome vem da empresa do usuário logado.
class LocalConsultorioRepository implements ConsultorioRepository {
  LocalConsultorioRepository(this._prefs, this._usuario);

  final SharedPreferences _prefs;
  final Usuario? Function() _usuario;

  static const _servicosIniciais = [
    Servico(id: 1, nome: 'Atendimento', duracaoMin: 30, valor: 0),
  ];

  String get _chave => 'consultorio_v1_${_usuario()?.tenantId ?? 0}';

  Map<String, dynamic> _ler() {
    final bruto = _prefs.getString(_chave);
    if (bruto == null) return {};
    try {
      return jsonDecode(bruto) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _gravar(Map<String, dynamic> dados) =>
      _prefs.setString(_chave, jsonEncode(dados));

  List<Servico> _servicos(Map<String, dynamic> dados) {
    final lista = dados['servicos'];
    if (lista is! List) return List.of(_servicosIniciais);
    return [for (final s in lista) Servico.fromJson(s as Map<String, dynamic>)];
  }

  @override
  Future<Consultorio> obter() async {
    final dados = _ler();
    final horarios = dados['horarios'];
    return Consultorio(
      nome: _usuario()?.empresa ?? '',
      endereco: dados['endereco'] as String? ?? '',
      horarios: horarios is List
          ? [
              for (final h in horarios)
                HorarioFuncionamento.fromJson(h as Map<String, dynamic>),
            ]
          : horariosPadrao,
    );
  }

  @override
  Future<Consultorio> salvar(Consultorio consultorio) async {
    final dados = _ler()
      ..['endereco'] = consultorio.endereco
      ..['horarios'] = [for (final h in consultorio.horarios) h.toJson()];
    await _gravar(dados);
    return consultorio.copyWith(nome: _usuario()?.empresa ?? consultorio.nome);
  }

  @override
  Future<List<Servico>> listarServicos() async => _servicos(_ler());

  @override
  Future<Servico> salvarServico(Servico servico) async {
    final dados = _ler();
    final servicos = _servicos(dados);
    var salvo = servico;
    if (servico.id == 0) {
      final proximo = (dados['proximoId'] as num?)?.toInt() ?? 100;
      salvo = Servico(
        id: proximo,
        nome: servico.nome,
        duracaoMin: servico.duracaoMin,
        valor: servico.valor,
      );
      servicos.add(salvo);
      dados['proximoId'] = proximo + 1;
    } else {
      final i = servicos.indexWhere((s) => s.id == servico.id);
      if (i < 0) throw const AppException('Serviço não encontrado.');
      servicos[i] = servico;
    }
    dados['servicos'] = [for (final s in servicos) s.toJson()];
    await _gravar(dados);
    return salvo;
  }

  @override
  Future<void> excluirServico(int id) async {
    final dados = _ler();
    final servicos = _servicos(dados)..removeWhere((s) => s.id == id);
    dados['servicos'] = [for (final s in servicos) s.toJson()];
    await _gravar(dados);
  }
}

class MockConsultorioRepository implements ConsultorioRepository {
  MockConsultorioRepository(this._db);

  final MockDb _db;

  @override
  Future<Consultorio> obter() async {
    await latenciaMock();
    return _db.consultorio;
  }

  @override
  Future<Consultorio> salvar(Consultorio consultorio) async {
    await latenciaMock();
    _db.consultorio = consultorio;
    return consultorio;
  }

  @override
  Future<List<Servico>> listarServicos() async {
    await latenciaMock();
    return List.of(_db.servicos);
  }

  @override
  Future<Servico> salvarServico(Servico servico) async {
    await latenciaMock();
    if (servico.id == 0) {
      final novo = Servico(
        id: _db.proximoId(),
        nome: servico.nome,
        duracaoMin: servico.duracaoMin,
        valor: servico.valor,
      );
      _db.servicos.add(novo);
      return novo;
    }
    final i = _db.servicos.indexWhere((s) => s.id == servico.id);
    if (i < 0) throw const AppException('Serviço não encontrado.');
    _db.servicos[i] = servico;
    return servico;
  }

  @override
  Future<void> excluirServico(int id) async {
    await latenciaMock();
    _db.servicos.removeWhere((s) => s.id == id);
  }
}
