import 'dart:convert';

import 'package:agendamento/core/errors.dart';
import 'package:agendamento/core/utils/formatters.dart';
import 'package:agendamento/data/api/api_client.dart';
import 'package:agendamento/data/mock/mock_db.dart';
import 'package:agendamento/data/models/empresa.dart';
import 'package:agendamento/data/models/usuario.dart';
import 'package:agendamento/data/repositories/auth_repository.dart';
import 'package:agendamento/data/repositories/empresas_repository.dart';
import 'package:agendamento/data/repositories/whatsapp_repository.dart';
import 'package:agendamento/data/storage/session_store.dart';
import 'package:agendamento/router/app_router.dart';
import 'package:agendamento/state/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Chamada {
  _Chamada(this.metodo, this.caminho, this.corpo);

  final String metodo;
  final String caminho;
  final dynamic corpo;
}

ApiClient _api(List<_Chamada> chamadas, http.Response Function(http.Request) r) {
  return ApiClient(
    baseUrl: 'http://api.teste',
    client: MockClient((req) async {
      chamadas.add(
        _Chamada(
          req.method,
          req.url.path + (req.url.hasQuery ? '?${req.url.query}' : ''),
          req.body.isEmpty ? null : jsonDecode(req.body),
        ),
      );
      return r(req);
    }),
  );
}

http.Response _json(Object corpo, [int status = 200]) => http.Response(
  jsonEncode(corpo),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _empresaJson({String situacao = 'ATIVA', bool ativo = true}) => {
  'id': 5,
  'nomeFantasia': 'Cronvia Teste',
  'documento': '99999999000199',
  'ativo': ativo,
  'plano': 'BASICO',
  'venceEm': '2026-12-22',
  'situacao': situacao,
  'totalClientes': 12,
  'totalAgendamentos': 34,
  'adminNome': 'Admin Teste',
  'adminEmail': 'teste.admin@cronvia.test',
};

void main() {
  group('Empresa (modelo)', () {
    test('lê o JSON da API', () {
      final e = Empresa.fromJson(_empresaJson());
      expect(e.id, 5);
      expect(e.documentoFormatado, '99.999.999/0001-99');
      expect(e.situacao, SituacaoEmpresa.ativa);
      expect(e.venceEm, DateTime(2026, 12, 22));
      expect(e.totalClientes, 12);
      expect(e.adminEmail, 'teste.admin@cronvia.test');
    });

    test('campos opcionais ausentes não quebram', () {
      final e = Empresa.fromJson({'id': 1, 'nomeFantasia': 'X', 'documento': '1', 'ativo': true});
      expect(e.plano, isNull);
      expect(e.venceEm, isNull);
      expect(e.diasParaVencer, isNull);
      expect(e.adminEmail, isNull);
    });

    test('situação desconhecida vira ativa', () {
      expect(SituacaoEmpresa.fromApi('OUTRA'), SituacaoEmpresa.ativa);
      expect(SituacaoEmpresa.fromApi('suspensa'), SituacaoEmpresa.suspensa);
    });

    test('dias para vencer: futuro, hoje e passado', () {
      final hoje = DateTime.now();
      int dias(int d) => Empresa(
        id: 1,
        nomeFantasia: 'X',
        documento: '1',
        ativo: true,
        situacao: SituacaoEmpresa.ativa,
        venceEm: DateTime(hoje.year, hoje.month, hoje.day + d),
      ).diasParaVencer!;
      expect(dias(10), 10);
      expect(dias(0), 0);
      expect(dias(-3), -3);
    });

    test('auditoria traduz as ações', () {
      final a = AuditoriaItem.fromJson({
        'id': 1,
        'quando': '2026-11-22T20:34:29.769079',
        'ator': 'admin@saas.com',
        'acao': 'EMPRESA_SUSPENSA',
      });
      expect(a.acaoLabel, 'Empresa suspensa');
      expect(a.quando.hour, 20);
      expect(AuditoriaItem.fromJson({'id': 2, 'acao': 'ALGO_NOVO'}).acaoLabel, 'ALGO_NOVO');
    });
  });

  group('documento e senha provisória', () {
    test('máscara de CPF e CNPJ', () {
      expect(formatarDocumento('12345678901'), '123.456.789-01');
      expect(formatarDocumento('99999999000199'), '99.999.999/0001-99');
      expect(formatarDocumento('123'), '123');
      expect(formatarDocumento('1234'), '123.4');
    });

    test('formatter limita a 14 dígitos', () {
      final f = DocumentoInputFormatter();
      String aplicar(String t) => f
          .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: t))
          .text;
      expect(aplicar('99999999000199999'), '99.999.999/0001-99');
    });

    test('senha provisória tem 12 caracteres sem letras ambíguas', () {
      for (var i = 0; i < 50; i++) {
        final s = gerarSenhaProvisoria();
        expect(s.length, 12);
        expect(RegExp(r'[0OIl1]').hasMatch(s), isFalse);
      }
      expect(gerarSenhaProvisoria(), isNot(gerarSenhaProvisoria()));
    });
  });

  group('ApiEmpresasRepository', () {
    test('lista empresas', () async {
      final api = _api([], (_) => _json([_empresaJson(), _empresaJson(situacao: 'SUSPENSA', ativo: false)]));
      final lista = await ApiEmpresasRepository(api).listar();
      expect(lista.length, 2);
      expect(lista.last.situacao, SituacaoEmpresa.suspensa);
    });

    test('cadastra com documento só em dígitos e vencimento ISO', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => _json(_empresaJson()));
      await ApiEmpresasRepository(api).criar(
        NovaEmpresa(
          nomeFantasia: 'Cronvia Teste',
          documento: '99999999000199',
          adminNome: 'Admin Teste',
          adminEmail: 'teste.admin@cronvia.test',
          adminSenha: 'Provisoria#2026',
          plano: 'BASICO',
          venceEm: DateTime(2026, 12, 22),
        ),
      );
      expect(chamadas.single.metodo, 'POST');
      expect(chamadas.single.caminho, '/api/v1/tenants/register');
      expect(chamadas.single.corpo, {
        'nomeFantasia': 'Cronvia Teste',
        'documento': '99999999000199',
        'adminNome': 'Admin Teste',
        'adminEmail': 'teste.admin@cronvia.test',
        'adminSenha': 'Provisoria#2026',
        'plano': 'BASICO',
        'venceEm': '2026-12-22',
      });
    });

    test('atualizar sem vencimento envia vazio (remove o vencimento)', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => _json(_empresaJson()));
      await ApiEmpresasRepository(api).atualizar(5, nomeFantasia: 'Novo nome', plano: 'PROFISSIONAL');
      expect(chamadas.single.metodo, 'PUT');
      expect(chamadas.single.caminho, '/api/v1/tenants/5');
      expect(chamadas.single.corpo, {
        'nomeFantasia': 'Novo nome',
        'plano': 'PROFISSIONAL',
        'venceEm': '',
      });
    });

    test('suspender e reativar', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => _json(_empresaJson(situacao: 'SUSPENSA', ativo: false)));
      final e = await ApiEmpresasRepository(api).definirAtivo(5, ativo: false);
      expect(chamadas.single.caminho, '/api/v1/tenants/5/ativo');
      expect(chamadas.single.corpo, {'ativo': false});
      expect(e.situacao, SituacaoEmpresa.suspensa);
    });

    test('redefinir senha devolve a provisória', () async {
      final chamadas = <_Chamada>[];
      final api = _api(
        chamadas,
        (_) => _json({'email': 'a@x.com', 'senhaTemporaria': 'Abc123Def456'}),
      );
      final s = await ApiEmpresasRepository(api).redefinirSenhaAdmin(5);
      expect(chamadas.single.metodo, 'POST');
      expect(chamadas.single.caminho, '/api/v1/tenants/5/redefinir-senha-admin');
      expect(s.email, 'a@x.com');
      expect(s.senha, 'Abc123Def456');
    });

    test('lê a auditoria', () async {
      final api = _api(
        [],
        (_) => _json([
          {'id': 2, 'quando': '2026-11-22T20:35:23', 'ator': 'admin@saas.com', 'acao': 'SENHA_ADMIN_REDEFINIDA', 'detalhe': 'Admin x'},
        ]),
      );
      final itens = await ApiEmpresasRepository(api).auditoria(5);
      expect(itens.single.acaoLabel, 'Senha do admin redefinida');
    });

    test('mensagens de erro da API chegam ao usuário', () async {
      final api = _api([], (_) => _json({'status': 400, 'message': 'Já existe uma empresa com este CPF/CNPJ.'}, 400));
      await expectLater(
        ApiEmpresasRepository(api).listar(),
        throwsA(isA<AppException>().having((e) => e.message, 'mensagem', contains('CPF/CNPJ'))),
      );
    });
  });

  group('ApiWhatsappRepository', () {
    test('status da empresa (MASTER informa tenantId)', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => _json({'instancia': 'tenant_5', 'estado': 'connecting', 'conectado': false}));
      final s = await ApiWhatsappRepository(api).status(tenantId: 5);
      expect(chamadas.single.caminho, '/api/v1/whatsapp/status?tenantId=5');
      expect(s.rotulo, 'Aguardando leitura do QR code');
      expect(s.conectado, isFalse);
    });

    test('ADMIN não envia tenantId', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => _json({'instancia': 'tenant_2', 'estado': 'open', 'conectado': true}));
      final s = await ApiWhatsappRepository(api).status();
      expect(chamadas.single.caminho, '/api/v1/whatsapp/status');
      expect(s.rotulo, 'Conectado');
    });

    test('conectar decodifica o QR code (data URI base64)', () async {
      const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
      final chamadas = <_Chamada>[];
      final api = _api(
        chamadas,
        (_) => _json({
          'instancia': 'tenant_5',
          'estado': 'qr',
          'conectado': false,
          'qrBase64': 'data:image/png;base64,$png',
          'codigoPareamento': null,
        }),
      );
      final qr = await ApiWhatsappRepository(api).conectar(tenantId: 5);
      expect(chamadas.single.metodo, 'POST');
      expect(chamadas.single.caminho, '/api/v1/whatsapp/conectar?tenantId=5');
      expect(qr.estado, 'qr');
      expect(qr.qr, base64Decode(png));
    });

    test('QR ainda sendo gerado não tem imagem', () async {
      final api = _api([], (_) => _json({'estado': 'connecting', 'conectado': false}));
      final qr = await ApiWhatsappRepository(api).conectar();
      expect(qr.qr, isNull);
    });

    test('serviço de WhatsApp fora do ar mostra a mensagem do servidor', () async {
      final api = _api(
        [],
        (_) => _json({'status': 503, 'message': 'Não foi possível falar com o serviço de WhatsApp. Verifique se ele está no ar.'}, 503),
      );
      await expectLater(
        ApiWhatsappRepository(api).status(tenantId: 5),
        throwsA(isA<AppException>().having((e) => e.message, 'mensagem', contains('WhatsApp'))),
      );
    });

    test('desconectar', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => _json({'instancia': 'tenant_5', 'estado': 'close', 'conectado': false}));
      final s = await ApiWhatsappRepository(api).desconectar(tenantId: 5);
      expect(chamadas.single.metodo, 'DELETE');
      expect(chamadas.single.caminho, '/api/v1/whatsapp/desconectar?tenantId=5');
      expect(s.rotulo, 'Desconectado');
    });
  });

  group('login e troca de senha', () {
    Map<String, dynamic> loginJson({bool trocar = false, String role = 'ADMIN'}) => {
      'token': 'jwt',
      'nome': 'Ana',
      'role': role,
      'tenantId': 5,
      'tenant': 'Clínica',
      'usuarioId': 7,
      'precisaTrocarSenha': trocar,
    };

    test('lê precisaTrocarSenha e o perfil', () async {
      final api = _api([], (_) => _json(loginJson(trocar: true, role: 'MASTER')));
      final s = await ApiAuthRepository(api).login('a@x.com', '12345678');
      expect(s.usuario.precisaTrocarSenha, isTrue);
      expect(s.usuario.ehMaster, isTrue);
    });

    test('empresa suspensa no login mostra a mensagem do servidor', () async {
      final api = _api([], (_) => _json({'status': 403, 'message': 'Empresa suspensa. Fale com o suporte.'}, 403));
      await expectLater(
        ApiAuthRepository(api).login('a@x.com', 'x'),
        throwsA(isA<AppException>().having((e) => e.message, 'mensagem', contains('suspensa'))),
      );
    });

    test('muitas tentativas (429) mostra a mensagem do servidor', () async {
      final api = _api([], (_) => _json({'status': 429, 'message': 'Muitas tentativas de login. Tente novamente em alguns minutos.'}, 429));
      await expectLater(
        ApiAuthRepository(api).login('a@x.com', 'x'),
        throwsA(isA<AppException>().having((e) => e.message, 'mensagem', contains('Muitas tentativas'))),
      );
    });

    test('alterar senha envia atual e nova', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => http.Response('', 204));
      await ApiAuthRepository(api).alterarSenha(atual: 'Provisoria#1', nova: 'NovaSenha#2026');
      expect(chamadas.single.caminho, '/api/v1/auth/alterar-senha');
      expect(chamadas.single.corpo, {'senhaAtual': 'Provisoria#1', 'novaSenha': 'NovaSenha#2026'});
    });

    test('senha atual incorreta volta com a mensagem da API', () async {
      final api = _api([], (_) => _json({'status': 400, 'message': 'A senha atual está incorreta.'}, 400));
      await expectLater(
        ApiAuthRepository(api).alterarSenha(atual: 'x', nova: 'NovaSenha#2026'),
        throwsA(isA<AppException>().having((e) => e.message, 'mensagem', 'A senha atual está incorreta.')),
      );
    });

    test('trocar a senha libera o app e atualiza a sessão salva', () async {
      final store = MemorySessionStore();
      final api = _api(
        [],
        (req) => req.url.path.endsWith('login') ? _json(loginJson(trocar: true)) : http.Response('', 204),
      );
      final auth = AuthController(ApiAuthRepository(api), store);
      await auth.login('a@x.com', 'Provisoria#1');
      expect(auth.precisaTrocarSenha, isTrue);

      await auth.alterarSenha(atual: 'Provisoria#1', nova: 'NovaSenha#2026');
      expect(auth.precisaTrocarSenha, isFalse);
      expect((await store.ler())!.usuario.precisaTrocarSenha, isFalse);
    });

    test('empresa bloqueada no meio do uso encerra a sessão e guarda o aviso', () async {
      final store = MemorySessionStore();
      final api = _api([], (_) => _json(loginJson()));
      final auth = AuthController(
        ApiAuthRepository(api),
        store,
        aoMudarToken: (t) => api.token = t,
      );
      api.aoBloquearAcesso = auth.bloquearAcesso;
      await auth.login('a@x.com', '12345678');
      expect(auth.logado, isTrue);

      final bloqueada = _api(
        [],
        (_) => _json({'status': 403, 'message': 'Empresa suspensa. Fale com o suporte.'}, 403),
      )
        ..token = 'jwt'
        ..aoBloquearAcesso = auth.bloquearAcesso;
      await expectLater(bloqueada.get('/api/v1/clientes'), throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero);

      expect(auth.logado, isFalse);
      expect(auth.consumirAviso(), contains('suspensa'));
      expect(auth.consumirAviso(), isNull, reason: 'o aviso some depois de lido');
    });

    test('403 de permissão comum não derruba a sessão', () async {
      var bloqueou = false;
      final api = _api([], (_) => _json({'status': 403}, 403))
        ..token = 'jwt'
        ..aoBloquearAcesso = (_) => bloqueou = true;
      await expectLater(api.get('/api/v1/tenants'), throwsA(isA<ApiException>()));
      expect(bloqueou, isFalse);
    });
  });

  group('decidirRedirect (rotas por papel)', () {
    String? r(String local, {bool logado = true, bool trocar = false, bool master = false}) =>
        decidirRedirect(local: local, logado: logado, precisaTrocarSenha: trocar, ehMaster: master);

    test('sem login só vai para o login; a abertura sempre roda', () {
      expect(r('/inicio', logado: false), '/login');
      expect(r('/master/empresas', logado: false), '/login');
      expect(r('/login', logado: false), isNull);
      expect(r('/splash', logado: false), isNull);
      expect(r('/splash'), isNull);
    });

    test('logado sai do login para a página inicial do papel', () {
      expect(r('/login'), '/inicio');
      expect(r('/login', master: true), '/master/empresas');
    });

    test('senha provisória prende na troca obrigatória', () {
      expect(r('/inicio', trocar: true), '/trocar-senha-obrigatoria');
      expect(r('/master/empresas', trocar: true, master: true), '/trocar-senha-obrigatoria');
      expect(r('/trocar-senha-obrigatoria', trocar: true), isNull);
    });

    test('depois da troca, sai da tela obrigatória', () {
      expect(r('/trocar-senha-obrigatoria'), '/inicio');
      expect(r('/trocar-senha-obrigatoria', master: true), '/master/empresas');
    });

    test('MASTER só circula no painel, perfil e senha', () {
      expect(r('/inicio', master: true), '/master/empresas');
      expect(r('/clientes', master: true), '/master/empresas');
      expect(r('/agendar', master: true), '/master/empresas');
      expect(r('/master/empresas/5', master: true), isNull);
      expect(r('/master/empresas/5/whatsapp', master: true), isNull);
      expect(r('/master/ajustes', master: true), isNull);
      expect(r('/senha', master: true), isNull);
      expect(r('/perfil', master: true), isNull);
    });

    test('clínica nunca entra no painel do MASTER', () {
      expect(r('/master/empresas'), '/inicio');
      expect(r('/master/empresas/5'), '/inicio');
      expect(r('/inicio'), isNull);
      expect(r('/whatsapp'), isNull);
      expect(r('/senha'), isNull);
    });
  });

  group('mock', () {
    test('e-mail com "master" entra como MASTER e "troca" exige trocar a senha', () async {
      final auth = AuthController(
        MockAuthRepository(MockDb()),
        MemorySessionStore(),
      );
      await auth.login('master@teste.com', '1234');
      expect(auth.usuario!.ehMaster, isTrue);
      await auth.sair();
      await auth.login('troca@teste.com', '1234');
      expect(auth.precisaTrocarSenha, isTrue);
    });

    test('empresas de exemplo: suspender, vencimento e a própria empresa', () async {
      final repo = MockEmpresasRepository();
      final lista = await repo.listar();
      expect(lista.any((e) => e.situacao == SituacaoEmpresa.suspensa), isTrue);
      expect(lista.any((e) => e.situacao == SituacaoEmpresa.vencida), isTrue);

      final suspensa = await repo.definirAtivo(2, ativo: false);
      expect(suspensa.situacao, SituacaoEmpresa.suspensa);
      await expectLater(repo.definirAtivo(1, ativo: false), throwsA(isA<AppException>()));
      expect((await repo.auditoria(2)).first.acaoLabel, 'Empresa suspensa');
    });

    test('whatsapp de exemplo conecta depois de algumas consultas', () async {
      final repo = MockWhatsappRepository();
      expect((await repo.status()).estado, 'inexistente');
      expect((await repo.conectar()).qr, isNotNull);
      WhatsappStatus s = await repo.status();
      for (var i = 0; i < 3 && !s.conectado; i++) {
        s = await repo.status();
      }
      expect(s.conectado, isTrue);
      expect((await repo.desconectar()).conectado, isFalse);
    });
  });

  test('Sessao guarda o perfil e a obrigação de trocar a senha', () async {
    final store = MemorySessionStore();
    await store.salvar(
      const Sessao(
        token: 't',
        usuario: Usuario(
          nome: 'A',
          email: 'a@x.com',
          role: 'MASTER',
          tenantId: 1,
          empresa: 'E',
          precisaTrocarSenha: true,
        ),
      ),
    );
    final lida = (await store.ler())!;
    expect(lida.usuario.ehMaster, isTrue);
    expect(Usuario.fromJson(lida.usuario.toJson()).precisaTrocarSenha, isTrue);
  });
}
