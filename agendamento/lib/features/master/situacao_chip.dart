import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/empresa.dart';

Color corDaSituacao(SituacaoEmpresa s) => switch (s) {
  SituacaoEmpresa.ativa => AppColors.primary,
  SituacaoEmpresa.suspensa => AppColors.danger,
  SituacaoEmpresa.vencida => AppColors.warning,
};

class SituacaoChip extends StatelessWidget {
  const SituacaoChip({super.key, required this.situacao});

  final SituacaoEmpresa situacao;

  @override
  Widget build(BuildContext context) {
    final cor = corDaSituacao(situacao);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            situacao.label,
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
