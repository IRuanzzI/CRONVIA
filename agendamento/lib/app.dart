import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config.dart';
import 'core/constants.dart';
import 'core/theme/app_theme.dart';
import 'data/api/api_client.dart';
import 'data/mock/mock_db.dart';
import 'data/repositories/agendamento_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/cliente_repository.dart';
import 'data/repositories/consultorio_repository.dart';
import 'data/repositories/empresas_repository.dart';
import 'data/repositories/whatsapp_repository.dart';
import 'data/storage/session_store.dart';
import 'router/app_router.dart';
import 'state/agenda_controller.dart';
import 'state/auth_controller.dart';
import 'state/clientes_controller.dart';
import 'state/consultorio_controller.dart';
import 'state/empresas_controller.dart';

/// Monta controllers e repositórios. É aqui que se escolhe entre a API real
/// e os dados de exemplo (`--dart-define=USE_MOCK=true`).
class AppDependencies {
  AppDependencies._({
    required this.auth,
    required this.clientes,
    required this.agenda,
    required this.consultorio,
    required this.empresas,
    required this.whatsapp,
    required this.api,
  });

  final AuthController auth;
  final ClientesController clientes;
  final AgendaController agenda;
  final ConsultorioController consultorio;

  /// Painel do MASTER.
  final EmpresasController empresas;
  final WhatsappRepository whatsapp;
  final ApiClient? api;

  static Future<AppDependencies> criar({
    bool? usarMock,
    ApiClient? api,
    SessionStore? sessao,
    SharedPreferences? prefs,
  }) async {
    final mock = usarMock ?? AppConfig.usarMock;
    late final AuthController auth;
    late final ClientesController clientes;
    late final AgendaController agenda;
    late final ConsultorioController consultorio;
    late final EmpresasController empresas;

    void limparTudo() {
      clientes.limpar();
      agenda.limpar();
      consultorio.limpar();
      empresas.limpar();
    }

    if (mock) {
      final db = MockDb();
      auth = AuthController(
        MockAuthRepository(db),
        sessao ?? MemorySessionStore(),
        aoSair: limparTudo,
      );
      clientes = ClientesController(MockClienteRepository(db));
      agenda = AgendaController(MockAgendamentoRepository(db));
      consultorio = ConsultorioController(MockConsultorioRepository(db));
      empresas = EmpresasController(MockEmpresasRepository());
      return AppDependencies._(
        auth: auth,
        clientes: clientes,
        agenda: agenda,
        consultorio: consultorio,
        empresas: empresas,
        whatsapp: MockWhatsappRepository(),
        api: null,
      );
    }

    final http = api ?? ApiClient(baseUrl: AppConfig.apiUrl);
    final preferencias = prefs ?? await SharedPreferences.getInstance();
    auth = AuthController(
      ApiAuthRepository(http),
      sessao ?? SecureSessionStore(),
      aoMudarToken: (t) => http.token = t,
      aoSair: limparTudo,
    );
    // Empresa suspensa/vencida no meio do uso: encerra a sessão e avisa.
    http.aoBloquearAcesso = auth.bloquearAcesso;
    clientes = ClientesController(ApiClienteRepository(http));
    agenda = AgendaController(ApiAgendamentoRepository(http));
    consultorio = ConsultorioController(
      LocalConsultorioRepository(preferencias, () => auth.usuario),
    );
    empresas = EmpresasController(ApiEmpresasRepository(http));
    await auth.restaurar();
    return AppDependencies._(
      auth: auth,
      clientes: clientes,
      agenda: agenda,
      consultorio: consultorio,
      empresas: empresas,
      whatsapp: ApiWhatsappRepository(http),
      api: http,
    );
  }
}

class AgendamentoApp extends StatefulWidget {
  const AgendamentoApp({super.key, required this.dependencias});

  final AppDependencies dependencias;

  @override
  State<AgendamentoApp> createState() => _AgendamentoAppState();
}

class _AgendamentoAppState extends State<AgendamentoApp> {
  late final GoRouter _router = criarRouter(widget.dependencias.auth);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dependencias;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: d.auth),
        ChangeNotifierProvider.value(value: d.clientes),
        ChangeNotifierProvider.value(value: d.agenda),
        ChangeNotifierProvider.value(value: d.consultorio),
        ChangeNotifierProvider.value(value: d.empresas),
        Provider<WhatsappRepository>.value(value: d.whatsapp),
      ],
      child: MaterialApp.router(
        title: appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: _router,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
