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

/// Items shown before the "ver todos" expander kicks in.
const _visibleItemLimit = 8;

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
  bool _showAllItems = false;

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
        const SnackBar(
          content: Text('Adjunta un comprobante antes de enviarlo.'),
        ),
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
          const SnackBar(
            content: Text('No se pudo actualizar el comprobante.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Comprobante actualizado.')));
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _OrderHeader(order: order),
                const SizedBox(height: 12),
                _CustomerCard(order: order),
                const SizedBox(height: 12),
                _ReceiptCard(
                  order: order,
                  paymentMethod: _paymentMethod,
                  paymentProofPath: _paymentProofPath,
                  uploading: _uploadingProof,
                  onMethodChanged: (value) =>
                      setState(() => _paymentMethod = value),
                  onPick: _pickPaymentProof,
                  onUpload: _uploadingProof ? null : _uploadPaymentProof,
                ),
                const SizedBox(height: 12),
                _ItemsCard(
                  items: order.items,
                  showAll: _showAllItems,
                  onToggleShowAll: () =>
                      setState(() => _showAllItems = !_showAllItems),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brandPrimaryDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Pedido #${order.orderNumber}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                AppFormatters.currency(order.totalAmount),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.dateTime(order.placedAt),
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusChip(value: order.status, dense: true),
              StatusChip(value: order.paymentStatus, dense: true),
              StatusChip(value: order.fulfillmentType, dense: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Cliente',
      children: [
        _CompactRow(label: 'Nombre', value: order.customerName),
        _CompactRow(label: 'Email', value: order.customerEmail ?? 'Sin email'),
        _CompactRow(
          label: 'Telefono',
          value: order.customerPhone ?? 'Sin telefono',
        ),
        _CompactRow(
          label: 'Entrega',
          value: localizedStatusLabel(order.fulfillmentType),
        ),
        _CompactRow(
          label: 'Pago',
          value: order.paymentMethod == null
              ? 'Sin metodo'
              : localizedStatusLabel(order.paymentMethod!),
        ),
        _CompactRow(
          label: 'Subtotal',
          value: AppFormatters.currency(order.subtotalAmount),
        ),
        _CompactRow(
          label: 'Total',
          value: AppFormatters.currency(order.totalAmount),
          emphasize: true,
        ),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.order,
    required this.paymentMethod,
    required this.paymentProofPath,
    required this.uploading,
    required this.onMethodChanged,
    required this.onPick,
    required this.onUpload,
  });

  final OrderDetail order;
  final String paymentMethod;
  final String? paymentProofPath;
  final bool uploading;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onPick;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRejection =
        order.paymentRejectionReason != null &&
        order.paymentRejectionReason!.trim().isNotEmpty;

    return _SectionCard(
      title: 'Comprobante',
      children: [
        Text(
          order.paymentReceiptImageUrl != null
              ? 'Comprobante actual disponible.'
              : 'Aun no hay comprobante cargado.',
          style: theme.textTheme.bodySmall,
        ),
        if (hasRejection) ...[
          const SizedBox(height: 6),
          Text(
            'Motivo de rechazo: ${order.paymentRejectionReason}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.red.shade700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: paymentMethod,
          isDense: true,
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
            if (value != null) {
              onMethodChanged(value);
            }
          },
          decoration: const InputDecoration(
            labelText: 'Metodo de pago',
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPick,
                child: Text(paymentProofPath == null ? 'Adjuntar' : 'Cambiar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: onUpload,
                child: Text(uploading ? 'Subiendo...' : 'Enviar'),
              ),
            ),
          ],
        ),
        if (paymentProofPath != null) ...[
          const SizedBox(height: 6),
          Text(
            paymentProofPath!.split(RegExp(r'[\\/]')).last,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (order.paymentReceiptSubmissions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Historial',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...order.paymentReceiptSubmissions.map(
            (submission) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${localizedStatusLabel(submission.paymentMethod)} · '
                      '${localizedStatusLabel(submission.reviewStatus)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    AppFormatters.dateTime(submission.submittedAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.items,
    required this.showAll,
    required this.onToggleShowAll,
  });

  final List<OrderDetailItem> items;
  final bool showAll;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overLimit = items.length > _visibleItemLimit;
    final visible = showAll || !overLimit
        ? items
        : items.take(_visibleItemLimit).toList(growable: false);
    final hiddenCount = items.length - visible.length;

    return _SectionCard(
      title: 'Productos (${items.length})',
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0)
            const Divider(height: 16, thickness: 0.5, color: AppColors.border),
          _ItemRow(item: visible[i]),
        ],
        if (overLimit) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onToggleShowAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                showAll ? 'Ver menos' : 'Ver $hiddenCount productos mas',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final OrderDetailItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.quantity}x ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            Expanded(
              child: Text(
                item.productName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppFormatters.currency(item.lineTotal),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.brandPrimaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        for (final component in item.comboComponents)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 22),
            child: Text(
              '• ${component.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        for (final modifier in item.modifiers)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 22),
            child: Text(
              '+ ${modifier.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: emphasize
                  ? theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
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
              Text(
                'No se pudo cargar el pedido',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('$error', style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Reintentar'),
              ),
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
    return const Center(
      child: Text('No hay detalle disponible para este pedido.'),
    );
  }
}
