import 'dart:convert';

import 'package:agendamento/core/errors.dart';
import 'package:agendamento/core/utils/formatters.dart';
import 'package:agendamento/data/api/api_client.dart';
import 'package:agendamento/data/models/agendamento.dart';
import 'package:agendamento/data/models/cliente.dart';
import 'package:agendamento/data/models/consultorio.dart';
import 'package:agendamento/data/models/servico.dart';
import 'package:agendamento/data/models/usuario.dart';
import 'package:agendamento/data/repositories/agendamento_repository.dart';
import 'package:agendamento/data/repositories/auth_repository.dart';
import 'package:agendamento/data/repositories/cliente_repository.dart';
import 'package:agendamento/data/repositories/consultorio_repository.dart';
import 'package:agendamento/data/storage/session_store.dart';
import 'package:agendamento/state/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Registro das chamadas feitas ao servidor falso.
class _Chamada {
  _Chamada(this.metodo, this.caminho, this.corpo, this.headers);

  final String metodo;
  final String caminho;
  final dynamic corpo;
  final Map<String, String> headers;
}

ApiClient _api(
  List<_Chamada> chamadas,
  http.Response Function(http.Request) resposta,
) {
  return ApiClient(
    baseUrl: 'http://api.teste',
    client: MockClient((req) async {
      chamadas.add(
        _Chamada(
          req.method,
          req.url.path + (req.url.hasQuery ? '?${req.url.query}' : ''),
          req.body.isEmpty ? null : jsonDecode(req.body),
          req.headers,
        ),
      );
      return resposta(req);
    }),
  );
}

http.Response _json(Object corpo, [int status = 200]) => http.Response(
  jsonEncode(corpo),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Agendamento como a API devolve hoje: sem `tenant` e sem o hash da senha do
/// usuário (ambos ficam fora do JSON).
Map<String, dynamic> _agendamentoJson({
  int id = 7,
  String status = 'CONFIRMADO',
  bool comUsuario = true,
}) => {
  'id': id,
  'cliente': {
    'id': 3,
    'nome': 'Maria Souza',
    'telefone': '5511912345678',
    'email': 'maria@x.com',
    'clienteDesde': '2026-01-10',
    'ultimoAtendimento': null,
  },
  'usuario': comUsuario
      ? {'id': 9, 'nome': 'Dra. Ana', 'email': 'ana@x.com', 'role': 'ADMIN'}
      : null,
  'data_hora_inicio': '2026-11-24T10:00:00',
  'data_hora_final': '2026-11-24T10:45:00',
  'status': status,
  'lembreteEnviado': true,
};

void main() {
  group('ApiClient', () {
    test('envia o token e decodifica JSON', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => _json({'ok': true}))..token = 'abc';
      final r = await api.get('/api/v1/x');
      expect(r, {'ok': true});
      expect(chamadas.single.headers['Authorization'], 'Bearer abc');
    });

    test('devolve texto puro quando não é JSON', () async {
      final api = _api([], (_) => http.Response.bytes(utf8.encode('Clínica X'), 200));
      expect(await api.get('/api/v1/tenants/me'), 'Clínica X');
    });

    test('204 sem corpo devolve null', () async {
      final api = _api([], (_) => http.Response('', 204));
      expect(await api.delete('/api/v1/x/1'), isNull);
    });

    test('403 vira mensagem de permissão', () async {
      final api = _api([], (_) => _json({'status': 403}, 403));
      await expectLater(
        api.get('/api/v1/clientes'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 403)
              .having((e) => e.message, 'mensagem', contains('permissão')),
        ),
      );
    });

    test('usa o campo message quando a API envia', () async {
      final api = _api([], (_) => _json({'message': 'E-mail já cadastrado'}, 400));
      await expectLater(
        api.get('/x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'mensagem',
            'E-mail já cadastrado',
          ),
        ),
      );
    });

    test('falha de conexão vira mensagem amigável', () async {
      final api = ApiClient(
        baseUrl: 'http://api.teste',
        client: MockClient((_) async => throw http.ClientException('sem rede')),
      );
      await expectLater(
        api.get('/x'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'mensagem',
            contains('conectar'),
          ),
        ),
      );
    });

    test('timeout vira mensagem amigável', () async {
      final api = ApiClient(
        baseUrl: 'http://api.teste',
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        api.get('/x'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'mensagem',
            contains('demorou'),
          ),
        ),
      );
    });
  });

  group('login', () {
    test('lê token, função, empresa e tenant', () async {
      final api = _api(
        [],
        (_) => _json({
          'token': 'jwt',
          'nome': 'Ruan',
          'role': 'ADMIN',
          'tenantId': 4,
          'tenant': 'Clínica Vida',
        }),
      );
      final sessao = await ApiAuthRepository(api).login('r@x.com', '123456');
      expect(sessao.token, 'jwt');
      expect(sessao.usuario.nome, 'Ruan');
      expect(sessao.usuario.role, 'ADMIN');
      expect(sessao.usuario.tenantId, 4);
      expect(sessao.usuario.empresa, 'Clínica Vida');
      expect(sessao.usuario.email, 'r@x.com');
    });

    test('envia e-mail e senha em /api/v1/auth/login', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => _json({'token': 't'}));
      await ApiAuthRepository(api).login('r@x.com', 'segredo');
      expect(chamadas.single.metodo, 'POST');
      expect(chamadas.single.caminho, '/api/v1/auth/login');
      expect(chamadas.single.corpo, {'email': 'r@x.com', 'senha': 'segredo'});
    });

    test('401 vira "e-mail ou senha incorretos"', () async {
      final api = _api(
        [],
        (_) => _json({'status': 401, 'message': 'Credenciais inválidas'}, 401),
      );
      await expectLater(
        ApiAuthRepository(api).login('a@a.com', 'x'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'mensagem',
            'E-mail ou senha incorretos.',
          ),
        ),
      );
    });

    test('500 é erro do servidor, não senha errada', () async {
      final api = _api([], (_) => _json({'status': 500}, 500));
      await expectLater(
        ApiAuthRepository(api).login('a@a.com', 'x'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'mensagem',
            contains('servidor'),
          ),
        ),
      );
    });

    test('lê o usuarioId quando a API devolve', () async {
      final api = _api([], (_) => _json({'token': 't', 'usuarioId': 12}));
      final sessao = await ApiAuthRepository(api).login('a@a.com', 'x');
      expect(sessao.usuario.id, 12);
    });

    test('resposta sem token (AuthResponse sem getters) avisa o motivo', () async {
      final api = _api([], (_) => _json(<String, dynamic>{}));
      await expectLater(
        ApiAuthRepository(api).login('a@a.com', 'x'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'mensagem',
            contains('AuthResponse'),
          ),
        ),
      );
    });
  });

  group('clientes', () {
    test('lista clientes com e-mail e data de cadastro', () async {
      final api = _api(
        [],
        (_) => _json([
          {
            'id': 1,
            'nome': 'Ana',
            'telefone': '5511999990000',
            'email': 'ana@x.com',
            'clienteDesde': '2026-03-12',
            'ultimoAtendimento': null,
          },
          {'id': 2, 'nome': 'Sem dados', 'telefone': '5511888880000'},
        ]),
      );
      final lista = await ApiClienteRepository(api).listar();
      expect(lista.first.nome, 'Ana');
      expect(lista.first.telefoneFormatado, '(11) 99999-0000');
      expect(lista.first.email, 'ana@x.com');
      expect(lista.first.desde, DateTime(2026, 3, 12));
      expect(lista.last.email, isEmpty);
      expect(lista.last.desde, isNull);
    });

    test('cria só com nome, telefone (dígitos com DDI 55) e e-mail', () async {
      final chamadas = <_Chamada>[];
      final api = _api(
        chamadas,
        (_) => _json({'id': 5, 'nome': 'Bia', 'telefone': '5511912345678'}),
      );
      final criado = await ApiClienteRepository(api).criar(
        nome: 'Bia',
        telefone: '(11) 91234-5678',
        email: 'bia@x.com',
      );
      expect(chamadas.single.caminho, '/api/v1/clientes/create');
      // A empresa e o "cliente desde" são definidos pela API.
      expect(chamadas.single.corpo, {
        'nome': 'Bia',
        'telefone': '5511912345678',
        'email': 'bia@x.com',
      });
      expect(criado.id, 5);
    });

    test('e-mail vazio não é enviado na criação', () async {
      final chamadas = <_Chamada>[];
      final api = _api(
        chamadas,
        (_) => _json({'id': 5, 'nome': 'Bia', 'telefone': '1'}),
      );
      await ApiClienteRepository(
        api,
      ).criar(nome: 'Bia', telefone: '(11) 91234-5678');
      expect((chamadas.single.corpo as Map).containsKey('email'), isFalse);
    });

    test('edição envia nome, telefone e e-mail (vazio limpa)', () async {
      final chamadas = <_Chamada>[];
      final api = _api(
        chamadas,
        (_) => _json({'id': 5, 'nome': 'Bia X', 'telefone': '5511912345678'}),
      );
      await ApiClienteRepository(api).atualizar(
        const Cliente(id: 5, nome: 'Bia X', telefone: '(11) 91234-5678'),
      );
      expect(chamadas.single.metodo, 'PUT');
      expect(chamadas.single.caminho, '/api/v1/clientes/edit/5');
      expect(chamadas.single.corpo, {
        'nome': 'Bia X',
        'telefone': '5511912345678',
        'email': '',
      });
    });

    test('exclusão com conflito mostra a mensagem do servidor', () async {
      final api = _api(
        [],
        (_) => _json({
          'status': 409,
          'message': 'Este registro está em uso e não pode ser removido.',
        }, 409),
      );
      await expectLater(
        ApiClienteRepository(api).excluir(5),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'mensagem',
            contains('em uso'),
          ),
        ),
      );
    });

    test('exclusão que falha com 500 explica o motivo provável', () async {
      final api = _api([], (_) => _json({'status': 500}, 500));
      await expectLater(
        ApiClienteRepository(api).excluir(5),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'mensagem',
            contains('agendamentos'),
          ),
        ),
      );
    });
  });

  group('agendamentos', () {
    test('lê o agendamento como a API devolve', () async {
      final api = _api([], (_) => _json([_agendamentoJson()]));
      final a = (await ApiAgendamentoRepository(api).listar()).single;
      expect(a.id, 7);
      expect(a.cliente.nome, 'Maria Souza');
      expect(a.profissional, 'Dra. Ana');
      expect(a.usuarioId, 9);
      expect(a.inicio, DateTime(2026, 11, 24, 10));
      expect(a.duracaoMin, 45);
      expect(a.status, StatusAgendamento.confirmado);
      expect(a.lembreteEnviado, isTrue);
    });

    test('registro malformado não derruba a lista', () async {
      final api = _api(
        [],
        (_) => _json([
          {'id': 1, 'data_hora_inicio': 'não é data'},
          _agendamentoJson(id: 2),
        ]),
      );
      final lista = await ApiAgendamentoRepository(api).listar();
      expect(lista.map((a) => a.id), [2]);
    });

    test('sem usuário nem data final, usa padrões seguros', () {
      final json = _agendamentoJson(comUsuario: false)
        ..remove('data_hora_final');
      final a = Agendamento.fromJson(json);
      expect(a.profissional, isNull);
      expect(a.duracaoMin, 30);
    });

    test('status desconhecido vira pendente', () {
      expect(StatusAgendamento.fromApi('AGENDADO'), StatusAgendamento.pendente);
      expect(
        StatusAgendamento.fromApi('cancelado'),
        StatusAgendamento.cancelado,
      );
      expect(StatusAgendamento.fromApi(null), StatusAgendamento.pendente);
    });

    test('cria só com cliente e datas ISO (a API define o resto)', () async {
      final chamadas = <_Chamada>[];
      final api = _api(
        chamadas,
        (_) => _json(_agendamentoJson(status: 'PENDENTE')),
      );
      final criado = await ApiAgendamentoRepository(api).criar(
        cliente: const Cliente(id: 3, nome: 'Maria', telefone: '5511912345678'),
        inicio: DateTime(2026, 11, 24, 10),
        fim: DateTime(2026, 11, 24, 10, 45),
      );
      expect(chamadas.single.metodo, 'POST');
      expect(chamadas.single.caminho, '/api/v1/agendamentos/create');
      expect(chamadas.single.corpo, {
        'cliente': {'id': 3},
        'data_hora_inicio': '2026-11-24T10:00:00',
        'data_hora_final': '2026-11-24T10:45:00',
      });
      expect(criado.status, StatusAgendamento.pendente);
    });

    test('mudar status envia cliente, datas e o novo status', () async {
      final chamadas = <_Chamada>[];
      final api = _api(
        chamadas,
        (_) => _json(_agendamentoJson(status: 'CANCELADO')),
      );
      final atual = Agendamento.fromJson(_agendamentoJson());
      final novo = await ApiAgendamentoRepository(
        api,
      ).atualizarStatus(atual, StatusAgendamento.cancelado);
      expect(chamadas.single.metodo, 'PUT');
      expect(chamadas.single.caminho, '/api/v1/agendamentos/edit/7');
      expect(chamadas.single.corpo, {
        'cliente': {'id': 3},
        'data_hora_inicio': '2026-11-24T10:00:00',
        'data_hora_final': '2026-11-24T10:45:00',
        'status': 'CANCELADO',
      });
      expect(novo.status, StatusAgendamento.cancelado);
    });

    test('exclui por id', () async {
      final chamadas = <_Chamada>[];
      final api = _api(chamadas, (_) => http.Response('', 204));
      await ApiAgendamentoRepository(api).excluir(7);
      expect(chamadas.single.metodo, 'DELETE');
      expect(chamadas.single.caminho, '/api/v1/agendamentos/delete/7');
    });
  });

  group('telefone', () {
    test('para a API: só dígitos com DDI', () {
      expect(telefoneParaApi('(11) 91234-5678'), '5511912345678');
      expect(telefoneParaApi('(11) 3333-4444'), '551133334444');
      expect(telefoneParaApi('5511912345678'), '5511912345678');
    });

    test('para exibir: tira o DDI e formata', () {
      expect(telefoneParaExibir('5511912345678'), '(11) 91234-5678');
      expect(telefoneParaExibir('551133334444'), '(11) 3333-4444');
      expect(telefoneParaExibir('(11) 91234-5678'), '(11) 91234-5678');
    });
  });

  group('sessão', () {
    Future<AuthController> controller(
      SessionStore store,
      List<String?> tokens,
    ) async {
      final api = _api(
        [],
        (_) => _json({
          'token': 'jwt',
          'nome': 'Ruan',
          'role': 'ADMIN',
          'tenantId': 1,
          'tenant': 'Clínica',
        }),
      );
      return AuthController(
        ApiAuthRepository(api),
        store,
        aoMudarToken: tokens.add,
      );
    }

    test('login guarda a sessão e entrega o token ao cliente HTTP', () async {
      final store = MemorySessionStore();
      final tokens = <String?>[];
      final auth = await controller(store, tokens);
      await auth.login('r@x.com', '123456');
      expect(auth.logado, isTrue);
      expect(tokens, ['jwt']);
      expect((await store.ler())?.token, 'jwt');
    });

    test('restaurar retoma a sessão salva', () async {
      final store = MemorySessionStore();
      await store.salvar(
        const Sessao(
          token: 'salvo',
          usuario: Usuario(
            nome: 'Ruan',
            email: 'r@x.com',
            role: 'ADMIN',
            tenantId: 1,
            empresa: 'Clínica',
          ),
        ),
      );
      final tokens = <String?>[];
      final auth = await controller(store, tokens);
      await auth.restaurar();
      expect(auth.logado, isTrue);
      expect(tokens, ['salvo']);
    });

    test('sair limpa token, sessão e dados', () async {
      final store = MemorySessionStore();
      final tokens = <String?>[];
      var limpou = false;
      final api = _api([], (_) => _json({'token': 'jwt'}));
      final auth = AuthController(
        ApiAuthRepository(api),
        store,
        aoMudarToken: tokens.add,
        aoSair: () => limpou = true,
      );
      await auth.login('r@x.com', '123456');
      await auth.sair();
      expect(auth.logado, isFalse);
      expect(tokens.last, isNull);
      expect(limpou, isTrue);
      expect(await store.ler(), isNull);
    });
  });

  group('consultório local', () {
    Future<LocalConsultorioRepository> repo(Usuario? Function() u) async {
      SharedPreferences.setMockInitialValues({});
      return LocalConsultorioRepository(await SharedPreferences.getInstance(), u);
    }

    const usuario = Usuario(
      nome: 'R',
      email: 'r@x.com',
      role: 'ADMIN',
      tenantId: 4,
      empresa: 'Clínica Vida',
    );

    test('usa o nome da empresa e horários padrão', () async {
      final r = await repo(() => usuario);
      final c = await r.obter();
      expect(c.nome, 'Clínica Vida');
      expect(c.horarios.length, horariosPadrao.length);
      expect(c.endereco, isEmpty);
    });

    test('guarda endereço e horários', () async {
      final r = await repo(() => usuario);
      final c = await r.obter();
      await r.salvar(
        c.copyWith(
          endereco: 'Rua A, 1',
          horarios: [c.horarios.first.copyWith(abreMin: 8 * 60), c.horarios[1]],
        ),
      );
      final lido = await r.obter();
      expect(lido.endereco, 'Rua A, 1');
      expect(lido.horarios.first.abreMin, 8 * 60);
    });

    test('serviços: padrão, criar, editar e excluir', () async {
      final r = await repo(() => usuario);
      expect((await r.listarServicos()).single.nome, 'Atendimento');

      final novo = await r.salvarServico(
        const Servico(id: 0, nome: 'Consulta', duracaoMin: 45, valor: 150),
      );
      expect(novo.id, isNot(0));
      expect((await r.listarServicos()).length, 2);

      await r.salvarServico(novo.copyWith(valor: 200));
      expect(
        (await r.listarServicos()).firstWhere((s) => s.id == novo.id).valor,
        200,
      );

      await r.excluirServico(novo.id);
      expect((await r.listarServicos()).length, 1);
    });
  });
}
