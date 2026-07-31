import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../application/orders_controller.dart';
import '../domain/orders_models.dart';
import '../infrastructure/orders_api.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.authSession,
    required this.ordersApi,
    required this.tenantSlug,
    required this.orderId,
  });

  final AuthSession authSession;
  final OrdersApi ordersApi;
  final String tenantSlug;
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrdersController _controller;
  late Future<OrderDetailPayload> _future;

  @override
  void initState() {
    super.initState();
    _controller = OrdersController(widget.ordersApi, widget.authSession);
    _future = _load();
  }

  Future<OrderDetailPayload> _load() {
    return _controller.loadOrderDetail(
      tenantSlug: widget.tenantSlug,
      orderId: widget.orderId,
    );
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pedido')),
      body: SafeArea(
        child: FutureBuilder<OrderDetailPayload>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _OrderDetailError(error: snapshot.error, onRetry: _retry);
            }

            final payload = snapshot.data;
            if (payload == null) {
              return const _OrderDetailEmpty();
            }

            final order = payload.order;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimaryDark,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${order.orderNumber}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${order.status} · ${order.paymentStatus}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cliente', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        _DetailRow(label: 'Nombre', value: order.customerName),
                        _DetailRow(label: 'Email', value: order.customerEmail ?? 'Sin email'),
                        _DetailRow(label: 'Telefono', value: order.customerPhone ?? 'Sin telefono'),
                        _DetailRow(label: 'Entrega', value: order.fulfillmentType),
                        _DetailRow(label: 'Pago', value: order.paymentMethod ?? 'Sin metodo'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Items', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        ...order.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: theme.textTheme.bodyLarge),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.quantity}x · ${item.lineTotal.toStringAsFixed(2)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: theme.textTheme.bodySmall)),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _OrderDetailError extends StatelessWidget {
  const _OrderDetailError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No se pudo cargar el pedido', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('$error', style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailEmpty extends StatelessWidget {
  const _OrderDetailEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No hay detalle disponible para este pedido.'));
  }
}
