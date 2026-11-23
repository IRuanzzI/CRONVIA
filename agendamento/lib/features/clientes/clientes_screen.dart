import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/cliente.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/initials_avatar.dart';
import '../../state/agenda_controller.dart';
import '../../state/clientes_controller.dart';

enum _Filtro {
  todos('Todos'),
  recentes('Recentes'),
  inativos('Inativos');

  const _Filtro(this.rotulo);
  final String rotulo;
}

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  String _busca = '';
  _Filtro _filtro = _Filtro.todos;

  bool _passaNoFiltro(DateTime? ultimo) {
    if (_filtro == _Filtro.todos) return true;
    final dias = ultimo == null
        ? null
        : DateTime.now().difference(ultimo).inDays;
    return switch (_filtro) {
      _Filtro.recentes => dias != null && dias <= 30,
      _Filtro.inativos => dias == null || dias > 60,
      _Filtro.todos => true,
    };
  }

  bool _passaNaBusca(Cliente c) {
    final termo = semAcento(_busca.trim().toLowerCase());
    if (termo.isEmpty) return true;
    final digitosBusca = termo.replaceAll(RegExp(r'\D'), '');
    final digitosTel = c.telefone.replaceAll(RegExp(r'\D'), '');
    return semAcento(c.nome.toLowerCase()).contains(termo) ||
        (digitosBusca.isNotEmpty && digitosTel.contains(digitosBusca));
  }

  @override
  Widget build(BuildContext context) {
    final clientesCtrl = context.watch<ClientesController>();
    final agenda = context.watch<AgendaController>();

    final linhas = <({Cliente cliente, DateTime? ultimo})>[
      for (final c in clientesCtrl.clientes)
        if (_passaNaBusca(c) &&
            _passaNoFiltro(agenda.ultimoAtendimento(c.id)))
          (cliente: c, ultimo: agenda.ultimoAtendimento(c.id)),
    ]..sort((a, b) =>
        semAcento(a.cliente.nome.toLowerCase())
            .compareTo(semAcento(b.cliente.nome.toLowerCase())));

    final itens = <Widget>[];
    String? letraAtual;
    for (final l in linhas) {
      final letra = semAcento(l.cliente.nome).substring(0, 1).toUpperCase();
      if (letra != letraAtual) {
        letraAtual = letra;
        itens.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4),
            child: Text(
              letra,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      }
      itens.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CardCliente(cliente: l.cliente, ultimo: l.ultimo),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Novo cliente',
        onPressed: () => context.push('/clientes/novo'),
        child: const Icon(Icons.person_add_alt_1_outlined, size: 26),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Clientes',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _busca = v),
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome ou telefone',
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in _Filtro.values) ...[
                      _ChipFiltro(
                        rotulo: f.rotulo,
                        selecionado: f == _filtro,
                        onTap: () => setState(() => _filtro = f),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: itens.isEmpty
                    ? EstadoVazio(
                        icone: clientesCtrl.erro != null
                            ? Icons.cloud_off_outlined
                            : Icons.people_outline,
                        texto: clientesCtrl.carregando
                            ? 'Carregando clientes...'
                            : clientesCtrl.erro ?? 'Nenhum cliente encontrado',
                        onAcao:
                            clientesCtrl.erro != null && !clientesCtrl.carregando
                            ? clientesCtrl.carregar
                            : null,
                      )
                    : RefreshIndicator(
                        onRefresh: clientesCtrl.carregar,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 96),
                          children: itens,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.rotulo,
    required this.selecionado,
    required this.onTap,
  });

  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionado ? AppColors.primary : AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: StadiumBorder(
        side: BorderSide(
          color: selecionado ? AppColors.primary : AppColors.border,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Center(
            child: Text(
              rotulo,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selecionado
                    ? AppColors.onPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardCliente extends StatelessWidget {
  const _CardCliente({required this.cliente, required this.ultimo});

  final Cliente cliente;
  final DateTime? ultimo;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/clientes/${cliente.id}'),
      child: Row(
        children: [
          InitialsAvatar(nome: cliente.nome, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ultimo == null
                      ? 'Sem atendimentos ainda'
                      : 'Último atendimento: ${ultimo!.year == DateTime.now().year ? formatarDiaMes(ultimo!) : formatarDataCurta(ultimo!)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
