import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Escolha do vencimento da assinatura: atalhos (+30 dias, +90 dias, +1 ano),
/// data específica ou "sem vencimento".
class VencimentoPicker extends StatelessWidget {
  const VencimentoPicker({super.key, required this.valor, required this.onChanged});

  final DateTime? valor;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _escolherData(BuildContext context) async {
    final hoje = soData(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: valor != null && !valor!.isBefore(hoje) ? valor! : hoje.add(const Duration(days: 30)),
      firstDate: hoje.subtract(const Duration(days: 365)),
      lastDate: hoje.add(const Duration(days: 365 * 10)),
      helpText: 'Vencimento da assinatura',
    );
    if (d != null) onChanged(soData(d));
  }

  @override
  Widget build(BuildContext context) {
    final hoje = soData(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vencimento',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () => _escolherData(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      valor == null ? 'Sem vencimento' : formatarData(valor!),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: valor == null ? FontWeight.w400 : FontWeight.w600,
                        color: valor == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.event_outlined, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Atalho('+30 dias', () => onChanged(hoje.add(const Duration(days: 30)))),
            _Atalho('+90 dias', () => onChanged(hoje.add(const Duration(days: 90)))),
            _Atalho('+1 ano', () => onChanged(DateTime(hoje.year + 1, hoje.month, hoje.day))),
            _Atalho('Sem vencimento', () => onChanged(null)),
          ],
        ),
      ],
    );
  }
}

class _Atalho extends StatelessWidget {
  const _Atalho(this.rotulo, this.onTap);

  final String rotulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(rotulo),
      onPressed: onTap,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }
}
