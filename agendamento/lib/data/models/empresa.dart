import 'dart:convert';
import 'dart:typed_data';

import '../../core/utils/formatters.dart';

enum SituacaoEmpresa {
  ativa('ATIVA', 'Ativa'),
  suspensa('SUSPENSA', 'Suspensa'),
  vencida('VENCIDA', 'Vencida');

  const SituacaoEmpresa(this.api, this.label);

  final String api;
  final String label;

  static SituacaoEmpresa fromApi(String? valor) => values.firstWhere(
    (s) => s.api == valor?.toUpperCase(),
    orElse: () => ativa,
  );
}

/// Empresa (clínica cliente) como o MASTER enxerga no painel.
class Empresa {
  const Empresa({
    required this.id,
    required this.nomeFantasia,
    required this.documento,
    required this.ativo,
    required this.situacao,
    this.plano,
    this.venceEm,
    this.totalClientes = 0,
    this.totalAgendamentos = 0,
    this.adminNome,
    this.adminEmail,
  });

  factory Empresa.fromJson(Map<String, dynamic> json) => Empresa(
    id: (json['id'] as num).toInt(),
    nomeFantasia: json['nomeFantasia'] as String? ?? '',
    documento: json['documento'] as String? ?? '',
    ativo: json['ativo'] as bool? ?? false,
    situacao: SituacaoEmpresa.fromApi(json['situacao'] as String?),
    plano: json['plano'] as String?,
    venceEm: DateTime.tryParse(json['venceEm'] as String? ?? ''),
    totalClientes: (json['totalClientes'] as num?)?.toInt() ?? 0,
    totalAgendamentos: (json['totalAgendamentos'] as num?)?.toInt() ?? 0,
    adminNome: json['adminNome'] as String?,
    adminEmail: json['adminEmail'] as String?,
  );

  final int id;
  final String nomeFantasia;

  /// Só dígitos (CPF ou CNPJ).
  final String documento;
  final bool ativo;
  final SituacaoEmpresa situacao;
  final String? plano;
  final DateTime? venceEm;
  final int totalClientes;
  final int totalAgendamentos;
  final String? adminNome;
  final String? adminEmail;

  String get documentoFormatado => formatarDocumento(documento);
  String get iniciais => iniciaisDe(nomeFantasia);

  /// Dias até o vencimento (negativo = já venceu; null = sem vencimento).
  int? get diasParaVencer {
    final v = venceEm;
    if (v == null) return null;
    return soData(v).difference(soData(DateTime.now())).inDays;
  }
}

/// Dados para cadastrar uma empresa e o admin dela.
class NovaEmpresa {
  const NovaEmpresa({
    required this.nomeFantasia,
    required this.documento,
    required this.adminNome,
    required this.adminEmail,
    required this.adminSenha,
    this.plano,
    this.venceEm,
  });

  final String nomeFantasia;
  final String documento;
  final String adminNome;
  final String adminEmail;

  /// Senha provisória: o admin é obrigado a trocar no primeiro acesso.
  final String adminSenha;
  final String? plano;
  final DateTime? venceEm;
}

class SenhaTemporaria {
  const SenhaTemporaria({required this.email, required this.senha});

  factory SenhaTemporaria.fromJson(Map<String, dynamic> json) => SenhaTemporaria(
    email: json['email'] as String? ?? '',
    senha: json['senhaTemporaria'] as String? ?? '',
  );

  final String email;
  final String senha;
}

/// Uma linha do histórico de ações (auditoria) de uma empresa.
class AuditoriaItem {
  const AuditoriaItem({
    required this.id,
    required this.quando,
    required this.ator,
    required this.acao,
    this.detalhe,
  });

  factory AuditoriaItem.fromJson(Map<String, dynamic> json) => AuditoriaItem(
    id: (json['id'] as num).toInt(),
    quando: DateTime.tryParse(json['quando'] as String? ?? '') ?? DateTime.now(),
    ator: json['ator'] as String? ?? 'sistema',
    acao: json['acao'] as String? ?? '',
    detalhe: json['detalhe'] as String?,
  );

  final int id;
  final DateTime quando;
  final String ator;
  final String acao;
  final String? detalhe;

  String get acaoLabel => switch (acao) {
    'EMPRESA_CRIADA' => 'Empresa criada',
    'EMPRESA_ATUALIZADA' => 'Dados atualizados',
    'EMPRESA_SUSPENSA' => 'Empresa suspensa',
    'EMPRESA_REATIVADA' => 'Empresa reativada',
    'SENHA_ADMIN_REDEFINIDA' => 'Senha do admin redefinida',
    'SENHA_ALTERADA' => 'Senha alterada',
    'AGENDAMENTO_CONFIRMADO' => 'Cliente confirmou pelo WhatsApp',
    'AGENDAMENTO_CANCELADO' => 'Cliente cancelou pelo WhatsApp',
    'WHATSAPP_QR_GERADO' => 'QR code do WhatsApp gerado',
    'WHATSAPP_DESCONECTADO' => 'WhatsApp desconectado',
    _ => acao,
  };
}

/// Estado da conexão de WhatsApp de uma empresa.
class WhatsappStatus {
  const WhatsappStatus({
    required this.instancia,
    required this.estado,
    required this.conectado,
  });

  factory WhatsappStatus.fromJson(Map<String, dynamic> json) => WhatsappStatus(
    instancia: json['instancia'] as String? ?? '',
    estado: json['estado'] as String? ?? 'close',
    conectado: json['conectado'] as bool? ?? false,
  );

  final String instancia;

  /// open, connecting, close ou inexistente.
  final String estado;
  final bool conectado;

  String get rotulo => switch (estado) {
    'open' => 'Conectado',
    'connecting' => 'Aguardando leitura do QR code',
    'inexistente' => 'Não configurado',
    _ => 'Desconectado',
  };
}

class WhatsappQr {
  const WhatsappQr({
    required this.estado,
    required this.conectado,
    this.qr,
    this.codigoPareamento,
  });

  factory WhatsappQr.fromJson(Map<String, dynamic> json) {
    Uint8List? bytes;
    final base64 = json['qrBase64'] as String?;
    if (base64 != null && base64.isNotEmpty) {
      try {
        // Vem como "data:image/png;base64,XXXX".
        bytes = base64Decode(base64.contains(',') ? base64.split(',').last : base64);
      } on FormatException {
        bytes = null;
      }
    }
    return WhatsappQr(
      estado: json['estado'] as String? ?? 'connecting',
      conectado: json['conectado'] as bool? ?? false,
      qr: bytes,
      codigoPareamento: json['codigoPareamento'] as String?,
    );
  }

  /// qr (tem imagem), connecting (gerando) ou open (já conectado).
  final String estado;
  final bool conectado;
  final Uint8List? qr;
  final String? codigoPareamento;
}
