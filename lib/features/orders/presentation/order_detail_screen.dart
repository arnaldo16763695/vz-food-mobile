import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/customer_footer_nav.dart';
import '../../../core/widgets/status_chip.dart';
import '../../bag/application/bag_count_controller.dart';
import '../../bag/infrastructure/bag_api.dart';
import '../application/orders_controller.dart';
import '../domain/orders_models.dart';
import '../infrastructure/orders_api.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.authSession,
    required this.bagApi,
    required this.bagCountController,
    required this.ordersApi,
    required this.tenantSlug,
    required this.orderId,
    required this.branchId,
  });

  final AuthSession authSession;
  final BagApi bagApi;
  final BagCountController bagCountController;
  final OrdersApi ordersApi;
  final String tenantSlug;
  final String orderId;
  final String? branchId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrdersController _controller;
  late Future<OrderDetailPayload> _future;
  final _imagePicker = ImagePicker();
  String? _paymentProofPath;
  String _paymentMethod = 'mobile_payment';
  bool _uploadingProof = false;

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

  Future<void> _pickPaymentProof() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }

    setState(() {
      _paymentProofPath = file.path;
    });
  }

  Future<void> _uploadPaymentProof() async {
    if (_paymentProofPath == null || _paymentProofPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjunta un comprobante antes de enviarlo.')),
      );
      return;
    }

    setState(() {
      _uploadingProof = true;
    });

    try {
      final ok = await _controller.uploadPaymentProof(
        tenantSlug: widget.tenantSlug,
        orderId: widget.orderId,
        paymentMethod: _paymentMethod,
        filePath: _paymentProofPath!,
      );

      if (!mounted) {
        return;
      }

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar el comprobante.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comprobante actualizado.')),
      );
      setState(() {
        _paymentProofPath = null;
        _future = _load();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir el comprobante: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingProof = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pedido')),
      bottomNavigationBar: CustomerFooterNav(
        currentTab: CustomerFooterTab.orders,
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        authSession: widget.authSession,
        bagApi: widget.bagApi,
        bagCountController: widget.bagCountController,
      ),
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
                        AppFormatters.dateTime(order.placedAt),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(value: order.status),
                          StatusChip(value: order.paymentStatus),
                        ],
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
                        _DetailRow(
                          label: 'Entrega',
                          value: localizedStatusLabel(order.fulfillmentType),
                        ),
                        _DetailRow(
                          label: 'Pago',
                          value: order.paymentMethod == null
                              ? 'Sin metodo'
                              : localizedStatusLabel(order.paymentMethod!),
                        ),
                        _DetailRow(
                          label: 'Subtotal',
                          value: AppFormatters.currency(order.subtotalAmount),
                        ),
                        _DetailRow(
                          label: 'Total',
                          value: AppFormatters.currency(order.totalAmount),
                        ),
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
                        Text('Comprobante', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (order.paymentReceiptImageUrl != null)
                          Text(
                            'Comprobante actual disponible',
                            style: theme.textTheme.bodyMedium,
                          )
                        else
                          Text(
                            'Aun no hay comprobante cargado para este pedido.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (order.paymentRejectionReason != null &&
                            order.paymentRejectionReason!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Motivo de rechazo: ${order.paymentRejectionReason}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _paymentMethod,
                          items: const [
                            DropdownMenuItem(
                              value: 'mobile_payment',
                              child: Text('Pago movil'),
                            ),
                            DropdownMenuItem(
                              value: 'bank_transfer',
                              child: Text('Transferencia bancaria'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _paymentMethod = value;
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Metodo de pago'),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _pickPaymentProof,
                          child: Text(
                            _paymentProofPath == null
                                ? 'Adjuntar comprobante'
                                : 'Cambiar comprobante',
                          ),
                        ),
                        if (_paymentProofPath != null) ...[
                          const SizedBox(height: 10),
                          Text(_paymentProofPath!, style: theme.textTheme.bodySmall),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _uploadingProof ? null : _uploadPaymentProof,
                          child: Text(
                            _uploadingProof
                                ? 'Subiendo...'
                                : 'Subir o reemplazar comprobante',
                          ),
                        ),
                        if (order.paymentReceiptSubmissions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Historial', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 12),
                          ...order.paymentReceiptSubmissions.map(
                            (submission) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '${localizedStatusLabel(submission.paymentMethod)} · ${localizedStatusLabel(submission.reviewStatus)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ],
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
                                  '${item.quantity}x · ${AppFormatters.currency(item.lineTotal)}',
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
