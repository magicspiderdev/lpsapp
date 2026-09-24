import 'package:intl/intl.dart';

final _euros = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

/// `36.5` → "36,50 €".
String euros(num valor) => _euros.format(valor);

/// "2026-08-20" ou "2026-08-20 18:00:00" → data, sem rebentar com formatos inesperados.
DateTime? dataApi(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

/// "20/08/2026".
String dataCurta(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

/// "20 ago. 2026".
String dataMedia(DateTime d) => DateFormat('d MMM y', 'pt_PT').format(d);

/// O primeiro nome, legível: a ficha de sócio vem em maiúsculas
/// ("CARMINHO EXEMPLO" → "Carminho").
String primeiroNome(String nome) {
  final p = nome.trim().split(RegExp(r'\s+')).first;
  if (p.isEmpty) return nome;
  return p[0].toUpperCase() + p.substring(1).toLowerCase();
}
