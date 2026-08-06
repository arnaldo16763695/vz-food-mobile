import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_formatters.dart';

String localizedStatusLabel(String value) {
  final normalized = value.trim().toLowerCase();

  return switch (normalized) {
    'ready_for_pickup' => 'Listo para retiro',
    'pending' => 'Pendiente',
    'processing' => 'En preparacion',
    'completed' => 'Completado',
    'delivered' => 'Entregado',
    'cancelled' => 'Cancelado',
    'failed' => 'Fallido',
    'rejected' => 'Rechazado',
    'accepted' => 'Aceptado',
    'paid' => 'Pagado',
    'refunded' => 'Reembolsado',
    'pickup' => 'Retiro',
    'delivery' => 'Entrega',
    'mobile_payment' => 'Pago movil',
    'bank_transfer' => 'Transferencia bancaria',
    'picked_up' => 'Retirado',
    _ => AppFormatters.titleizeToken(value),
  };
}

Color statusColor(String value) {
  final normalized = value.trim().toLowerCase();

  return switch (normalized) {
    'ready_for_pickup' => Colors.green.shade700,
    'completed' || 'paid' || 'accepted' => Colors.teal.shade700,
    'processing' => Colors.blue.shade700,
    'pending' => Colors.orange.shade700,
    'delivery' => Colors.indigo.shade700,
    'pickup' => Colors.purple.shade700,
    'mobile_payment' => Colors.cyan.shade700,
    'bank_transfer' => Colors.deepPurple.shade700,
    'picked_up' || 'delivered' => Colors.green.shade800,
    'failed' || 'rejected' || 'cancelled' => Colors.red.shade700,
    'refunded' => Colors.brown.shade700,
    _ => AppColors.brandPrimaryDark,
  };
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.value,
  });

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = statusColor(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            localizedStatusLabel(value),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
