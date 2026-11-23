import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF0E1114);
  static const surface = Color(0xFF181B1F);
  static const surfaceAlt = Color(0xFF23272C);
  static const border = Color(0xFF2A2E34);

  /// Verde neon da logo Cronvia: cor de destaque do app inteiro.
  static const primary = Color(0xFF00FF2F);
  static const onPrimary = Color(0xFF07140B);

  /// Fundo do item em destaque (ex.: próximo atendimento): verde da marca
  /// bem diluído no fundo escuro.
  static const primaryContainer = Color(0xFF0D2917);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF9AA0A8);

  /// Mesmo verde da logo (usado na abertura animada).
  static const marca = primary;

  static const danger = Color(0xFFF28B82);
  static const warning = Color(0xFFF2C76B);
}
