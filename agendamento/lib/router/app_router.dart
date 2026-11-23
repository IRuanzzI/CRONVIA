import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/agenda/agenda_screen.dart';
import '../features/agenda/agendar_screen.dart';
import '../features/ajustes/ajustes_screen.dart';
import '../features/ajustes/perfil_screen.dart';
import '../features/ajustes/trocar_senha_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/clientes/cliente_detalhe_screen.dart';
import '../features/clientes/cliente_form_screen.dart';
import '../features/clientes/clientes_screen.dart';
import '../features/consultorio/consultorio_screen.dart';
import '../features/home/home_screen.dart';
import '../features/master/empresa_detalhe_screen.dart';
import '../features/master/empresa_form_screen.dart';
import '../features/master/master_empresas_screen.dart';
import '../features/notificacoes/notificacoes_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/whatsapp/whatsapp_screen.dart';
import '../shell/app_shell.dart';
import '../shell/master_shell.dart';
import '../state/auth_controller.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Transição suave (fade) para as telas principais, sem o "slide" padrão.
CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );

const _inicioClinica = '/inicio';
const _inicioMaster = '/master/empresas';
const _trocaObrigatoria = '/trocar-senha-obrigatoria';

/// Para onde mandar o usuário no momento (null = pode ficar onde está).
///
/// - Sem login: só o login.
/// - Senha provisória: só a troca obrigatória.
/// - MASTER: só o painel (`/master/...`), a troca de senha e o perfil.
/// - Clínica (ADMIN/USUARIO): nunca o painel do MASTER.
@visibleForTesting
String? decidirRedirect({
  required String local,
  required bool logado,
  required bool precisaTrocarSenha,
  required bool ehMaster,
}) {
  // A abertura animada sempre roda; depois ela vai para /inicio.
  if (local == '/splash') return null;
  final noLogin = local == '/login';
  if (!logado) return noLogin ? null : '/login';

  final casa = ehMaster ? _inicioMaster : _inicioClinica;
  if (precisaTrocarSenha)
    return local == _trocaObrigatoria ? null : _trocaObrigatoria;
  if (noLogin || local == _trocaObrigatoria) return casa;

  final noPainel = local.startsWith('/master');
  if (ehMaster) {
    const livres = {'/senha', '/perfil'};
    return (noPainel || livres.contains(local)) ? null : _inicioMaster;
  }
  return noPainel ? _inicioClinica : null;
}

GoRouter criarRouter(AuthController auth) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) => decidirRedirect(
      local: state.matchedLocation,
      logado: auth.logado,
      precisaTrocarSenha: auth.precisaTrocarSenha,
      ehMaster: auth.usuario?.ehMaster ?? false,
    ),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fade(state, const LoginScreen()),
      ),
      GoRoute(
        path: _trocaObrigatoria,
        pageBuilder: (_, state) =>
            _fade(state, const TrocarSenhaScreen(obrigatoria: true)),
      ),

      // ---------------------------------------------------- clínica (ADMIN/USUARIO)
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) =>
            _fade(state, AppShell(navigationShell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/inicio', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/agenda', builder: (_, _) => const AgendaScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clientes',
                builder: (_, _) => const ClientesScreen(),
                routes: [
                  GoRoute(
                    path: 'novo',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const ClienteFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => ClienteDetalheScreen(
                      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    ),
                    routes: [
                      GoRoute(
                        path: 'editar',
                        parentNavigatorKey: _rootKey,
                        builder: (_, state) => ClienteFormScreen(
                          clienteId: int.tryParse(
                            state.pathParameters['id'] ?? '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ajustes',
                builder: (_, _) => const AjustesScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------------- painel do MASTER
      StatefulShellRoute.indexedStack(
        pageBuilder: (_, state, shell) =>
            _fade(state, MasterShell(navigationShell: shell)),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/master/empresas',
                builder: (_, _) => const MasterEmpresasScreen(),
                routes: [
                  GoRoute(
                    path: 'nova',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const EmpresaFormScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => EmpresaDetalheScreen(
                      id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
                    ),
                    routes: [
                      GoRoute(
                        path: 'whatsapp',
                        parentNavigatorKey: _rootKey,
                        builder: (_, state) => WhatsappScreen(
                          tenantId: int.tryParse(
                            state.pathParameters['id'] ?? '',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/master/ajustes',
                builder: (_, _) => const AjustesScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------------- telas comuns
      GoRoute(
        path: '/agendar',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => AgendarScreen(
          clienteId: int.tryParse(state.uri.queryParameters['clienteId'] ?? ''),
          data: DateTime.tryParse(state.uri.queryParameters['data'] ?? ''),
        ),
      ),
      GoRoute(
        path: '/consultorio',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ConsultorioScreen(),
      ),
      GoRoute(
        path: '/whatsapp',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const WhatsappScreen(),
      ),
      GoRoute(
        path: '/perfil',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const PerfilScreen(),
      ),
      GoRoute(
        path: '/senha',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const TrocarSenhaScreen(),
      ),
      GoRoute(
        path: '/notificacoes',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const NotificacoesScreen(),
      ),
    ],
  );
}
