import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// Orders per page. The backend returns the full history in one call, so
/// paging is done client-side to keep the list short and scannable.
const _ordersPageSize = 6;

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.authSession,
    required this.bagApi,
    required this.bagCountController,
    required this.ordersApi,
    required this.tenantSlug,
    required this.branchId,
  });

  final AuthSession authSession;
  final BagApi bagApi;
  final BagCountController bagCountController;
  final OrdersApi ordersApi;
  final String tenantSlug;
  final String? branchId;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrdersController _controller;
  late Future<OrdersPayload> _future;
  final _scrollController = ScrollController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = OrdersController(widget.ordersApi, widget.authSession);
    _future = _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<OrdersPayload> _load() {
    return _controller.loadOrders(tenantSlug: widget.tenantSlug);
  }

  void _retry() {
    setState(() {
      _page = 0;
      _future = _load();
    });
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _page = 0;
      _future = future;
    });
    await future;
  }

  void _goToPage(int page) {
    setState(() => _page = page);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _openOrder(OrderSummary order) {
    final branchQuery = widget.branchId == null || widget.branchId!.isEmpty
        ? ''
        : '?branchId=${widget.branchId}';
    context.push(
      '/storefront/${widget.tenantSlug}/orders/${order.id}$branchQuery',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos')),
      bottomNavigationBar: CustomerFooterNav(
        currentTab: CustomerFooterTab.orders,
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        authSession: widget.authSession,
        bagApi: widget.bagApi,
        bagCountController: widget.bagCountController,
      ),
      body: SafeArea(
        child: FutureBuilder<OrdersPayload>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _OrdersError(error: snapshot.error, onRetry: _retry);
            }

            final payload = snapshot.data;
            if (payload == null || payload.isEmpty) {
              return const _OrdersEmpty();
            }

            final orders = payload.orders;
            final totalPages = math.max(
              1,
              (orders.length / _ordersPageSize).ceil(),
            );
            final page = _page.clamp(0, totalPages - 1);
            final start = page * _ordersPageSize;
            final pageOrders = orders.sublist(
              start,
              math.min(start + _ordersPageSize, orders.length),
            );

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _OrdersHeader(total: orders.length),
                  const SizedBox(height: 12),
                  ...pageOrders.map(
                    (order) => _OrderSummaryCard(
                      order: order,
                      onTap: () => _openOrder(order),
                    ),
                  ),
                  if (totalPages > 1)
                    _PaginationBar(
                      page: page,
                      totalPages: totalPages,
                      onPrev: page > 0 ? () => _goToPage(page - 1) : null,
                      onNext: page < totalPages - 1
                          ? () => _goToPage(page + 1)
                          : null,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'Tus pedidos',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$total',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.brandPrimaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '#${order.orderNumber}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      AppFormatters.currency(order.totalAmount),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.brandPrimaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusChip(value: order.status, dense: true),
                    StatusChip(value: order.fulfillmentType, dense: true),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${order.itemCount} items · ${AppFormatters.dateTime(order.placedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            label: const Text('Anterior'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          Text(
            'Pagina ${page + 1} de $totalPages',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextButton(
            onPressed: onNext,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Siguiente'),
                Icon(Icons.chevron_right_rounded, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersError extends StatelessWidget {
  const _OrdersError({required this.error, required this.onRetry});

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
                'No se pudieron cargar pedidos',
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

class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Todavia no hay pedidos para este tenant.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
