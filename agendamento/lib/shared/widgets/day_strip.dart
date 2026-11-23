import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Faixa com os 7 dias da semana da data selecionada (segunda a domingo).
class DayStrip extends StatelessWidget {
  const DayStrip({super.key, required this.selecionado, required this.onSelect});

  final DateTime selecionado;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final inicio = inicioDaSemana(selecionado);
    final hoje = DateTime.now();

    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _Dia(
              dia: somarDias(inicio, i),
              rotulo: diasSemanaCurto[i],
              selecionado: mesmoDia(somarDias(inicio, i), selecionado),
              ehHoje: mesmoDia(somarDias(inicio, i), hoje),
              onTap: () => onSelect(somarDias(inicio, i)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({
    required this.dia,
    required this.rotulo,
    required this.selecionado,
    required this.ehHoje,
    required this.onTap,
  });

  final DateTime dia;
  final String rotulo;
  final bool selecionado;
  final bool ehHoje;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corTexto = selecionado ? AppColors.onPrimary : AppColors.textPrimary;
    return Material(
      color: selecionado ? AppColors.primary : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selecionado
              ? AppColors.primary
              : ehHoje
              ? AppColors.primary.withValues(alpha: .5)
              : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rotulo,
                style: TextStyle(
                  color: corTexto,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${dia.day}',
                style: TextStyle(
                  color: corTexto,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
