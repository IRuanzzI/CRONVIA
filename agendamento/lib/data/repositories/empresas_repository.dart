import 'package:intl/intl.dart';

import '../../core/errors.dart';
import '../api/api_client.dart';
import '../mock/mock_db.dart';
import '../models/empresa.dart';

String _dataApi(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Painel do MASTER: gestão das empresas (clínicas) clientes.
abstract class EmpresasRepository {
  Future<List<Empresa>> listar();
  Future<Empresa> criar(NovaEmpresa nova);
  Future<Empresa> atualizar(
    int id, {
    required String nomeFantasia,
    String? plano,
    DateTime? venceEm,
  });
  Future<Empresa> definirAtivo(int id, {required bool ativo});
  Future<SenhaTemporaria> redefinirSenhaAdmin(int id);
  Future<List<AuditoriaItem>> auditoria(int id);
}

class ApiEmpresasRepository implements EmpresasRepository {
  ApiEmpresasRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Empresa>> listar() async {
    final json = await _api.get('/api/v1/tenants');
    return [
      for (final item in json as List) Empresa.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<Empresa> criar(NovaEmpresa nova) async {
    final json = await _api.post(
      '/api/v1/tenants/register',
      corpo: {
        'nomeFantasia': nova.nomeFantasia,
        'documento': nova.documento,
        'adminNome': nova.adminNome,
        'adminEmail': nova.adminEmail,
        'adminSenha': nova.adminSenha,
        if (nova.plano != null) 'plano': nova.plano,
        if (nova.venceEm != null) 'venceEm': _dataApi(nova.venceEm!),
      },
    );
    return Empresa.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Empresa> atualizar(
    int id, {
    required String nomeFantasia,
    String? plano,
    DateTime? venceEm,
  }) async {
    final json = await _api.put(
      '/api/v1/tenants/$id',
      corpo: {
        'nomeFantasia': nomeFantasia,
        'plano': plano ?? '',
        // Vazio remove o vencimento.
        'venceEm': venceEm == null ? '' : _dataApi(venceEm),
      },
    );
    return Empresa.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<Empresa> definirAtivo(int id, {required bool ativo}) async {
    final json = await _api.put(
      '/api/v1/tenants/$id/ativo',
      corpo: {'ativo': ativo},
    );
    return Empresa.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<SenhaTemporaria> redefinirSenhaAdmin(int id) async {
    final json = await _api.post('/api/v1/tenants/$id/redefinir-senha-admin');
    return SenhaTemporaria.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<List<AuditoriaItem>> auditoria(int id) async {
    final json = await _api.get('/api/v1/tenants/$id/auditoria');
    return [
      for (final item in json as List)
        AuditoriaItem.fromJson(item as Map<String, dynamic>),
    ];
  }
}

/// Empresas de exemplo (modo `USE_MOCK`), tudo em memória.
class MockEmpresasRepository implements EmpresasRepository {
  MockEmpresasRepository() {
    final hoje = DateTime.now();
    _empresas = [
      Empresa(
        id: 1,
        nomeFantasia: 'SaaS do Ruan',
        documento: '00011122200013',
        ativo: true,
        situacao: SituacaoEmpresa.ativa,
        plano: 'INTERNO',
        totalClientes: 0,
        totalAgendamentos: 0,
      ),
      Empresa(
        id: 2,
        nomeFantasia: 'Clínica Vida Plena',
        documento: '12345678000190',
        ativo: true,
        situacao: SituacaoEmpresa.ativa,
        plano: 'PROFISSIONAL',
        venceEm: DateTime(hoje.year, hoje.month + 3, hoje.day),
        totalClientes: 128,
        totalAgendamentos: 540,
        adminNome: 'Dra. Marina Lopes',
        adminEmail: 'marina@vidaplena.com',
      ),
      Empresa(
        id: 3,
        nomeFantasia: 'Odonto Sorriso',
        documento: '98765432000110',
        ativo: false,
        situacao: SituacaoEmpresa.suspensa,
        plano: 'BASICO',
        totalClientes: 42,
        totalAgendamentos: 96,
        adminNome: 'Carlos Souza',
        adminEmail: 'carlos@odontosorriso.com',
      ),
      Empresa(
        id: 4,
        nomeFantasia: 'Studio Bem-Estar',
        documento: '11122233344',
        ativo: true,
        situacao: SituacaoEmpresa.vencida,
        plano: 'BASICO',
        venceEm: hoje.subtract(const Duration(days: 6)),
        totalClientes: 17,
        totalAgendamentos: 31,
        adminNome: 'Paula Andrade',
        adminEmail: 'paula@bemestar.com',
      ),
    ];
  }

  late List<Empresa> _empresas;
  final Map<int, List<AuditoriaItem>> _auditoria = {};
  int _proximoId = 10;
  int _proximaAuditoria = 1;

  Empresa _com(Empresa e, {bool? ativo, String? nome, String? plano, DateTime? venceEm, bool limparVencimento = false}) {
    final novoVence = limparVencimento ? null : (venceEm ?? e.venceEm);
    final ativoFinal = ativo ?? e.ativo;
    final situacao = !ativoFinal
        ? SituacaoEmpresa.suspensa
        : (novoVence != null && novoVence.isBefore(DateTime.now()))
        ? SituacaoEmpresa.vencida
        : SituacaoEmpresa.ativa;
    return Empresa(
      id: e.id,
      nomeFantasia: nome ?? e.nomeFantasia,
      documento: e.documento,
      ativo: ativoFinal,
      situacao: situacao,
      plano: plano ?? e.plano,
      venceEm: novoVence,
      totalClientes: e.totalClientes,
      totalAgendamentos: e.totalAgendamentos,
      adminNome: e.adminNome,
      adminEmail: e.adminEmail,
    );
  }

  void _registrar(int id, String acao, [String? detalhe]) {
    _auditoria.putIfAbsent(id, () => []).insert(
      0,
      AuditoriaItem(
        id: _proximaAuditoria++,
        quando: DateTime.now(),
        ator: 'admin@saas.com',
        acao: acao,
        detalhe: detalhe,
      ),
    );
  }

  Empresa _buscar(int id) {
    final i = _empresas.indexWhere((e) => e.id == id);
    if (i < 0) throw const AppException('Empresa não encontrada.');
    return _empresas[i];
  }

  void _trocar(Empresa nova) {
    _empresas = [for (final e in _empresas) e.id == nova.id ? nova : e];
  }

  @override
  Future<List<Empresa>> listar() async {
    await latenciaMock();
    return List.of(_empresas);
  }

  @override
  Future<Empresa> criar(NovaEmpresa nova) async {
    await latenciaMock();
    if (_empresas.any((e) => e.documento == nova.documento)) {
      throw const AppException('Já existe uma empresa com este CPF/CNPJ.');
    }
    final empresa = Empresa(
      id: _proximoId++,
      nomeFantasia: nova.nomeFantasia,
      documento: nova.documento,
      ativo: true,
      situacao: SituacaoEmpresa.ativa,
      plano: nova.plano ?? 'TESTE',
      venceEm: nova.venceEm,
      adminNome: nova.adminNome,
      adminEmail: nova.adminEmail,
    );
    _empresas = [..._empresas, empresa];
    _registrar(empresa.id, 'EMPRESA_CRIADA', 'Admin ${nova.adminEmail}');
    return empresa;
  }

  @override
  Future<Empresa> atualizar(
    int id, {
    required String nomeFantasia,
    String? plano,
    DateTime? venceEm,
  }) async {
    await latenciaMock();
    final nova = _com(
      _buscar(id),
      nome: nomeFantasia,
      plano: plano,
      venceEm: venceEm,
      limparVencimento: venceEm == null,
    );
    _trocar(nova);
    _registrar(id, 'EMPRESA_ATUALIZADA');
    return nova;
  }

  @override
  Future<Empresa> definirAtivo(int id, {required bool ativo}) async {
    await latenciaMock();
    if (!ativo && id == 1) {
      throw const AppException('Você não pode suspender a sua própria empresa.');
    }
    final nova = _com(_buscar(id), ativo: ativo);
    _trocar(nova);
    _registrar(id, ativo ? 'EMPRESA_REATIVADA' : 'EMPRESA_SUSPENSA');
    return nova;
  }

  @override
  Future<SenhaTemporaria> redefinirSenhaAdmin(int id) async {
    await latenciaMock();
    final e = _buscar(id);
    if (e.adminEmail == null) {
      throw const AppException('Esta empresa não tem um administrador.');
    }
    _registrar(id, 'SENHA_ADMIN_REDEFINIDA', 'Admin ${e.adminEmail}');
    return SenhaTemporaria(email: e.adminEmail!, senha: 'Demo1234Abc');
  }

  @override
  Future<List<AuditoriaItem>> auditoria(int id) async {
    await latenciaMock();
    return List.of(_auditoria[id] ?? const []);
  }
}
