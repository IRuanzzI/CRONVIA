import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/widgets/info_rows.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../../shared/widgets/screen_header.dart';
import '../../state/auth_controller.dart';

/// Dados da conta (somente leitura: a API ainda não tem edição de perfil).
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  static String _funcao(String role) => switch (role) {
    'MASTER' => 'Master',
    'ADMIN' => 'Administrador',
    'USUARIO' => 'Usuário',
    _ => role.isEmpty ? '—' : role,
  };

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AuthController>().usuario;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const ScreenHeader(titulo: 'Meu perfil'),
            const SizedBox(height: 24),
            Center(child: InitialsAvatar(nome: u?.nome ?? '', size: 96)),
            const SizedBox(height: 28),
            InfoRows(
              rows: [
                InfoRow('Nome', u?.nome ?? '—'),
                InfoRow('E-mail', u?.email ?? '—'),
                InfoRow('Função', _funcao(u?.role ?? '')),
                InfoRow(
                  'Empresa',
                  (u?.empresa ?? '').isEmpty ? '—' : u!.empresa,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
