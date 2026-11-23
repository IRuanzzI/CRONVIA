import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../shared/widgets/feedback.dart';
import '../state/empresas_controller.dart';
import '../state/auth_controller.dart';

/// Estrutura do perfil MASTER: Empresas e Ajustes (sem as abas de clínica).
class MasterShell extends StatefulWidget {
  const MasterShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MasterShell> createState() => _MasterShellState();
}

class _MasterShellState extends State<MasterShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmpresasController>().carregar();
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
            if (i == 2) {
              final sair = await confirmar(
                context,
                titulo: 'Sair da conta?',
                mensagem:
                    'Você precisará entrar novamente para acessar o painel.',
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
              icon: Icon(Icons.apartment_outlined),
              activeIcon: Icon(Icons.apartment_rounded),
              label: 'Empresas',
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
