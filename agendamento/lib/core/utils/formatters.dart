import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

const diasSemanaCurto = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

String iniciaisDe(String nome) {
  final partes = nome
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();
  return (partes.first[0] + partes.last[0]).toUpperCase();
}

String capitalizar(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const para = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  var r = s;
  for (var i = 0; i < de.length; i++) {
    r = r.replaceAll(de[i], para[i]);
  }
  return r;
}

String formatarMoeda(double valor) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(valor);

/// Aceita "150", "150,50", "150.50" ou "1.250,00".
double? lerMoeda(String texto) {
  final t = texto.replaceAll(r'R$', '').trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
  }
  return double.tryParse(t);
}

String duracaoLabel(int minutos) {
  if (minutos < 60) return '$minutos min';
  final h = minutos ~/ 60;
  final m = minutos % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
}

String minutosParaHora(int minutos) =>
    '${(minutos ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutos % 60).toString().padLeft(2, '0')}';

String formatarHora(DateTime d) => DateFormat('HH:mm').format(d);
String formatarData(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String formatarDiaMes(DateTime d) => DateFormat('dd/MM').format(d);
String formatarDataCurta(DateTime d) => DateFormat('dd/MM/yy').format(d);
String formatarMesAno(DateTime d) =>
    capitalizar(DateFormat('MMMM y', 'pt_BR').format(d));

/// Formato que a API (Spring) espera em `data_hora_inicio` / `data_hora_final`.
String paraIsoApi(DateTime d) =>
    DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(d);

bool mesmoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime soData(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime inicioDaSemana(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

DateTime somarDias(DateTime d, int dias) =>
    DateTime(d.year, d.month, d.day + dias, d.hour, d.minute);

/// Como a API guarda o telefone: só dígitos, com DDI 55.
///
/// O webhook do WhatsApp compara o número que chega (ex.: 5511912345678)
/// com o telefone salvo no cliente, então precisam estar no mesmo formato.
String telefoneParaApi(String texto) {
  var digitos = texto.replaceAll(RegExp(r'\D'), '');
  if (digitos.length == 10 || digitos.length == 11) digitos = '55$digitos';
  return digitos;
}

/// Telefone da API (ou já formatado) no formato (11) 91234-5678.
String telefoneParaExibir(String bruto) {
  var d = bruto.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('55') && (d.length == 12 || d.length == 13)) {
    d = d.substring(2);
  }
  if (d.length == 11) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  }
  if (d.length == 10) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  }
  return bruto;
}

/// CPF (000.000.000-00) ou CNPJ (00.000.000/0000-00), conforme os dígitos.
String formatarDocumento(String bruto) {
  final d = bruto.replaceAll(RegExp(r'\D'), '');
  final padrao = d.length <= 11 ? '000.000.000-00' : '00.000.000/0000-00';
  final b = StringBuffer();
  var i = 0;
  for (final c in padrao.split('')) {
    if (i >= d.length) break;
    if (c == '0') {
      b.write(d[i++]);
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

class DocumentoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 14) d = d.substring(0, 14);
    final texto = formatarDocumento(d);
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Senha provisória aleatória de 12 caracteres, sem letras que se confundem
/// (0/O, 1/l/I).
String gerarSenhaProvisoria() {
  const alfabeto =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  final r = math.Random.secure();
  return List.generate(12, (_) => alfabeto[r.nextInt(alfabeto.length)]).join();
}

class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 11) digitos = digitos.substring(0, 11);
    final b = StringBuffer();
    for (var i = 0; i < digitos.length; i++) {
      if (i == 0) b.write('(');
      if (i == 2) b.write(') ');
      if (digitos.length > 10 ? i == 7 : i == 6) b.write('-');
      b.write(digitos[i]);
    }
    final texto = b.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
