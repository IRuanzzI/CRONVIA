import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/agendamento.dart';

Color corDoStatus(StatusAgendamento status) => switch (status) {
  StatusAgendamento.confirmado => AppColors.primary,
  StatusAgendamento.pendente => AppColors.warning,
  StatusAgendamento.cancelado => AppColors.danger,
  StatusAgendamento.finalizado => AppColors.textSecondary,
};

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final StatusAgendamento status;

  @override
  Widget build(BuildContext context) {
    final cor = corDoStatus(status);
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
            status.label,
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
