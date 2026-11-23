import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

void mostrarMensagem(BuildContext context, String texto, {bool erro = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        texto,
        style: TextStyle(color: erro ? AppColors.danger : null),
      ),
    ),
  );
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String confirmarLabel = 'Confirmar',
  bool destrutivo = false,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        titulo,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
      ),
      content: Text(
        mensagem,
        style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Voltar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: destrutivo ? AppColors.danger : AppColors.primary,
          ),
          child: Text(confirmarLabel),
        ),
      ],
    ),
  );
  return resultado ?? false;
}

class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.texto,
    this.onAcao,
    this.acaoRotulo = 'Tentar de novo',
  });

  final IconData icone;
  final String texto;
  final VoidCallback? onAcao;
  final String acaoRotulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icone, size: 44, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          if (onAcao != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onAcao,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: Text(acaoRotulo),
            ),
          ],
        ],
      ),
    );
  }
}
