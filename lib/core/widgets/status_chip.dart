import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_formatters.dart';

String localizedStatusLabel(String value) {
  final normalized = value.trim().toLowerCase();

  return switch (normalized) {
    // Order lifecycle
    'new' => 'Nuevo',
    'pending' || 'pending_confirmation' => 'Pendiente',
    'confirmed' => 'Confirmado',
    'accepted' => 'Aceptado',
    'processing' ||
    'preparing' ||
    'in_preparation' ||
    'in_progress' => 'En preparacion',
    'ready' => 'Listo',
    'ready_for_pickup' => 'Listo para retiro',
    'on_the_way' || 'out_for_delivery' || 'in_transit' => 'En camino',
    'picked_up' => 'Retirado',
    'delivered' => 'Entregado',
    'completed' => 'Completado',
    'cancelled' || 'canceled' => 'Cancelado',
    'rejected' => 'Rechazado',
    'failed' => 'Fallido',
    'expired' => 'Expirado',
    'scheduled' => 'Programado',
    // Payment status
    'unpaid' ||
    'awaiting_payment' ||
    'pending_payment' ||
    'payment_pending' => 'Pago pendiente',
    'partially_paid' => 'Pago parcial',
    'in_review' ||
    'under_review' ||
    'awaiting_review' ||
    'payment_review' => 'En revision',
    'paid' => 'Pagado',
    'refunded' => 'Reembolsado',
    // Fulfillment + method
    'pickup' => 'Retiro',
    'delivery' => 'Entrega',
    'mobile_payment' => 'Pago movil',
    'bank_transfer' => 'Transferencia bancaria',
    _ => AppFormatters.titleizeToken(value),
  };
}

Color statusColor(String value) {
  final normalized = value.trim().toLowerCase();

  return switch (normalized) {
    'ready' || 'ready_for_pickup' => Colors.green.shade700,
    'completed' || 'paid' || 'accepted' || 'confirmed' => Colors.teal.shade700,
    'processing' ||
    'preparing' ||
    'in_preparation' ||
    'in_progress' => Colors.blue.shade700,
    'new' ||
    'pending' ||
    'pending_confirmation' ||
    'scheduled' => Colors.orange.shade700,
    'unpaid' ||
    'awaiting_payment' ||
    'pending_payment' ||
    'payment_pending' ||
    'partially_paid' => Colors.orange.shade800,
    'in_review' ||
    'under_review' ||
    'awaiting_review' ||
    'payment_review' => Colors.amber.shade800,
    'on_the_way' ||
    'out_for_delivery' ||
    'in_transit' ||
    'delivery' => Colors.indigo.shade700,
    'pickup' => Colors.purple.shade700,
    'mobile_payment' => Colors.cyan.shade700,
    'bank_transfer' => Colors.deepPurple.shade700,
    'picked_up' || 'delivered' => Colors.green.shade800,
    'failed' ||
    'rejected' ||
    'cancelled' ||
    'canceled' ||
    'expired' => Colors.red.shade700,
    'refunded' => Colors.brown.shade700,
    _ => AppColors.brandPrimaryDark,
  };
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.value, this.dense = false});

  final String value;

  /// Tighter padding and a smaller dot for use inside compact lists.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = statusColor(value);
    final dot = dense ? 6.0 : 8.0;

    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: dense ? 6 : 8),
          Text(
            localizedStatusLabel(value),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 11 : null,
            ),
          ),
        ],
      ),
    );
  }
}
