import 'package:intl/intl.dart';

class AppFormatters {
  const AppFormatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'es_DO',
    symbol: r'$ ',
    decimalDigits: 2,
  );

  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  static String currency(num amount) => _currency.format(amount);

  static String dateTime(DateTime? value) {
    if (value == null) {
      return 'Sin fecha';
    }

    return _dateTime.format(value.toLocal());
  }

  static String titleizeToken(String raw) {
    if (raw.trim().isEmpty) {
      return 'Sin estado';
    }

    return raw
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
