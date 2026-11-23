import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../shared/widgets/feedback.dart';
import '../state/agenda_controller.dart';
import '../state/auth_controller.dart';
import '../state/clientes_controller.dart';
import '../state/consultorio_controller.dart';

/// Estrutura com a barra inferior (Início, Agenda, Clientes e Ajustes).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    // Carrega os dados depois do login (com a API real, o token já existe).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ConsultorioController>().carregar();
      context.read<ClientesController>().carregar();
      context.read<AgendaController>().carregar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.navigationShell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: shell.currentIndex,
          onTap: (i) async {
            if (i == 4) {
              final sair = await confirmar(
                context,
                titulo: 'Sair da conta?',
                mensagem:
                    'Você precisará entrar novamente para acessar o aplicativo.',
                confirmarLabel: 'Sair',
                destrutivo: true,
              );
              if (sair && context.mounted) {
                await context.read<AuthController>().sair();
              }
              return;
            }
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 13,
          unselectedFontSize: 13,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Início',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today_rounded),
              label: 'Agenda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people_alt_rounded),
              label: 'Clientes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Ajustes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.exit_to_app_outlined),
              activeIcon: Icon(Icons.exit_to_app_rounded),
              label: 'Sair',
            ),
          ],
        ),
      ),
    );
  }
}
