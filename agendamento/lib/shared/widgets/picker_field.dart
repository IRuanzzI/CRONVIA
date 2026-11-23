import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Campo que abre uma lista de opções (visual de "dropdown").
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.rotulo,
    required this.placeholder,
    required this.onTap,
    this.valor,
  });

  final String rotulo;
  final String placeholder;
  final String? valor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: const TextStyle(
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
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      valor ?? placeholder,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        color: valor == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontWeight: valor == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String titulo,
  required List<T> itens,
  required String Function(T) rotuloDe,
  String Function(T)? subtituloDe,
  bool buscavel = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PickerSheet<T>(
      titulo: titulo,
      itens: itens,
      rotuloDe: rotuloDe,
      subtituloDe: subtituloDe,
      buscavel: buscavel,
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.titulo,
    required this.itens,
    required this.rotuloDe,
    required this.subtituloDe,
    required this.buscavel,
  });

  final String titulo;
  final List<T> itens;
  final String Function(T) rotuloDe;
  final String Function(T)? subtituloDe;
  final bool buscavel;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final termo = semAcento(_busca.toLowerCase());
    final itens = widget.itens
        .where(
          (i) =>
              termo.isEmpty ||
              semAcento(widget.rotuloDe(i).toLowerCase()).contains(termo),
        )
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Text(
                  widget.titulo,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.buscavel)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _busca = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              Flexible(
                child: itens.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Nada encontrado',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: itens.length,
                        itemBuilder: (context, i) {
                          final item = itens[i];
                          final sub = widget.subtituloDe?.call(item);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            title: Text(
                              widget.rotuloDe(item),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: sub == null
                                ? null
                                : Text(
                                    sub,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
