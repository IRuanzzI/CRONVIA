import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 52,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Tooltip(
          message: tooltip ?? '',
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho das telas empilhadas: botão voltar + título.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.titulo, this.trailing});

  final String titulo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RoundIconButton(
          icon: Icons.chevron_left,
          tooltip: 'Voltar',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/inicio'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
