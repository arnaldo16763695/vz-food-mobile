import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/customer_footer_nav.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../application/bag_count_controller.dart';
import '../application/bag_controller.dart';
import '../application/bag_load_result.dart';
import '../domain/bag_payload.dart';
import '../infrastructure/bag_api.dart';

class BagScreen extends StatefulWidget {
  const BagScreen({
    super.key,
    required this.bagApi,
    required this.bagCountController,
    required this.authSession,
    required this.tenantSlug,
    required this.branchId,
  });

  final BagApi bagApi;
  final BagCountController bagCountController;
  final AuthSession authSession;
  final String tenantSlug;
  final String branchId;

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  late final BagController _controller;
  BagLoadResult? _result;
  Object? _loadError;
  bool _loading = true;
  String? _mutatingItemId;

  @override
  void initState() {
    super.initState();
    _controller = BagController(widget.bagApi, widget.authSession);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final result = await _controller.load(
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _loading = false;
      });
      widget.bagCountController.setCountForContext(
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        count: result.payload?.items.fold<int>(0, (sum, item) => sum + item.quantity) ?? 0,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _refreshAfterMutation() async {
    final previousItems = _result?.payload?.items ?? const <BagItem>[];

    try {
      final result = await _controller.load(
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = BagLoadResult(
          status: result.status,
          payload: result.payload?.copyWith(
            items: _preserveVisualOrder(previousItems, result.payload?.items),
          ),
        );
      });
      widget.bagCountController.setCountForContext(
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        count: _result?.payload?.items.fold<int>(0, (sum, item) => sum + item.quantity) ?? 0,
      );
    } catch (_) {
      // Keep the optimistic state if background refresh fails.
    }
  }

  List<BagItem> _preserveVisualOrder(
    List<BagItem> previousItems,
    List<BagItem>? refreshedItems,
  ) {
    if (refreshedItems == null || refreshedItems.isEmpty) {
      return refreshedItems ?? const <BagItem>[];
    }

    final refreshedById = {
      for (final item in refreshedItems) item.id: item,
    };
    final ordered = <BagItem>[];

    for (final item in previousItems) {
      final refreshed = refreshedById.remove(item.id);
      if (refreshed != null) {
        ordered.add(refreshed);
      }
    }

    ordered.addAll(refreshedById.values);
    return ordered;
  }

  void _retry() {
    _load();
  }

  BagItem? _currentItemById(String itemId) {
    final items = _result?.payload?.items;
    if (items == null) {
      return null;
    }

    for (final item in items) {
      if (item.id == itemId) {
        return item;
      }
    }

    return null;
  }

  Future<void> _incrementItem(BagItem item) async {
    await _runBagMutation(
      itemId: item.id,
      optimisticUpdate: (payload) {
        return payload.copyWith(
          items: payload.items
              .map(
                (candidate) => candidate.id == item.id
                    ? candidate.copyWith(quantity: candidate.quantity + 1)
                    : candidate,
              )
              .toList(growable: false),
        );
      },
      action: (accessToken) {
        final currentItem = _currentItemById(item.id) ?? item;
        return widget.bagApi.replaceItem(
          tenantSlug: widget.tenantSlug,
          bagItemId: item.id,
          accessToken: accessToken,
          branchId: widget.branchId,
          productId: item.productId,
          quantity: currentItem.quantity,
          productVariantId: currentItem.productVariantId,
          modifierSelections: currentItem.modifierSelections
              .map((selection) => selection.toRequestJson())
              .toList(growable: false),
        );
      },
    );
  }

  Future<void> _decrementItem(BagItem item) async {
    await _runBagMutation(
      itemId: item.id,
      optimisticUpdate: (payload) {
        final updatedItems = <BagItem>[];
        for (final candidate in payload.items) {
          if (candidate.id != item.id) {
            updatedItems.add(candidate);
            continue;
          }

          final nextQuantity = candidate.quantity - 1;
          if (nextQuantity > 0) {
            updatedItems.add(candidate.copyWith(quantity: nextQuantity));
          }
        }

        return payload.copyWith(items: updatedItems);
      },
      action: (accessToken) {
        return widget.bagApi.decrementItem(
          tenantSlug: widget.tenantSlug,
          bagItemId: item.id,
          branchId: widget.branchId,
          accessToken: accessToken,
        );
      },
    );
  }

  Future<void> _removeItem(BagItem item) async {
    await _runBagMutation(
      itemId: item.id,
      optimisticUpdate: (payload) {
        return payload.copyWith(
          items: payload.items
              .where((candidate) => candidate.id != item.id)
              .toList(growable: false),
        );
      },
      action: (accessToken) {
        return widget.bagApi.removeItem(
          tenantSlug: widget.tenantSlug,
          bagItemId: item.id,
          branchId: widget.branchId,
          accessToken: accessToken,
        );
      },
    );
  }

  Future<void> _runBagMutation({
    required String itemId,
    required BagPayload Function(BagPayload payload) optimisticUpdate,
    required Future<void> Function(String accessToken) action,
  }) async {
    final accessToken = await widget.authSession.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        context.push(
          '/account?tenantSlug=${widget.tenantSlug}&branchId=${widget.branchId}',
        );
      }
      return;
    }

    final currentResult = _result;
    final currentPayload = currentResult?.payload;
    if (currentResult == null || currentPayload == null) {
      return;
    }

    final previousPayload = currentPayload;

    setState(() {
      _mutatingItemId = itemId;
      _result = BagLoadResult(
        status: currentResult.status,
        payload: optimisticUpdate(currentPayload),
      );
    });
    widget.bagCountController.setCountForContext(
      tenantSlug: widget.tenantSlug,
      branchId: widget.branchId,
      count: _result?.payload?.items.fold<int>(0, (sum, item) => sum + item.quantity) ?? 0,
    );

    try {
      await action(accessToken);
      if (!mounted) {
        return;
      }

      setState(() {
        _mutatingItemId = null;
      });
      unawaited(_refreshAfterMutation());
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _result = BagLoadResult(
          status: currentResult.status,
          payload: previousPayload,
        );
      });
      widget.bagCountController.setCountForContext(
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        count: previousPayload.items.fold<int>(0, (sum, item) => sum + item.quantity),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la bolsa de compra: $error'),
        ),
      );
    } finally {
      if (mounted && _mutatingItemId == itemId) {
        setState(() {
          _mutatingItemId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = _result?.payload;

    return Scaffold(
      appBar: AppBar(title: const Text('Bolsa de compra')),
      bottomNavigationBar: CustomerFooterNav(
        currentTab: CustomerFooterTab.bag,
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        authSession: widget.authSession,
        bagApi: widget.bagApi,
        bagCountController: widget.bagCountController,
      ),
      bottomSheet: payload == null || payload.isEmpty
          ? null
          : _CheckoutBottomBar(payload: payload),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: payload == null || payload.isEmpty ? 0 : 96,
          ),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return _BagError(error: _loadError, onRetry: _retry);
    }

    final result = _result;
    if (result == null) {
      return const _BagEmpty();
    }

    if (result.requiresLogin) {
      return _BagRequiresLogin(
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
      );
    }

    final payload = result.payload;
    if (payload == null || payload.isEmpty) {
      return const _BagEmpty();
    }

    return _BagView(
      payload: payload,
      mutatingItemId: _mutatingItemId,
      onDecrement: _decrementItem,
      onIncrement: _incrementItem,
      onRemove: _removeItem,
    );
  }
}

class _BagView extends StatelessWidget {
  const _BagView({
    required this.payload,
    required this.mutatingItemId,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  final BagPayload payload;
  final String? mutatingItemId;
  final Future<void> Function(BagItem item) onDecrement;
  final Future<void> Function(BagItem item) onIncrement;
  final Future<void> Function(BagItem item) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.accentWarm,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Tu bolsa de compra', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'La cantidad cambia al instante para que el cliente sienta una interaccion mas fluida mientras la red se sincroniza en segundo plano.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...payload.items.map(
          (item) => _BagItemCard(
            item: item,
            isMutating: mutatingItemId == item.id,
            onDecrement: () => onDecrement(item),
            onIncrement: () => onIncrement(item),
            onRemove: () => onRemove(item),
          ),
        ),
      ],
    );
  }
}

class _CheckoutBottomBar extends StatelessWidget {
  const _CheckoutBottomBar({required this.payload});

  final BagPayload payload;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.push(
              '/storefront/${payload.items.first.tenantSlug}/checkout?branchId=${payload.items.first.branchId}',
            ),
            child: const Text('Ir a checkout'),
          ),
        ),
      ),
    );
  }
}

class _BagRequiresLogin extends StatelessWidget {
  const _BagRequiresLogin({
    required this.tenantSlug,
    required this.branchId,
  });

  final String tenantSlug;
  final String branchId;

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
              Text('Login requerido', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'La bolsa de compra es una superficie autenticada. La pantalla ya esta lista para el endpoint real, pero falta conectar Supabase Auth para obtener el Bearer token del cliente.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push(
                  '/account?tenantSlug=$tenantSlug&branchId=$branchId',
                ),
                child: const Text('Ir a cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BagEmpty extends StatelessWidget {
  const _BagEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'La bolsa de compra esta vacia para esta sucursal.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _BagError extends StatelessWidget {
  const _BagError({required this.error, required this.onRetry});

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
                'No se pudo cargar la bolsa de compra',
                style: theme.textTheme.titleLarge,
              ),
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

class _BagItemCard extends StatelessWidget {
  const _BagItemCard({
    required this.item,
    required this.isMutating,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  final BagItem item;
  final bool isMutating;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineTotal = item.unitPrice * item.quantity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(item.category, style: theme.textTheme.bodySmall),
              const SizedBox(height: 10),
              Text(item.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  QuantityStepper(
                    quantity: item.quantity,
                    onDecrement: onDecrement,
                    onIncrement: onIncrement,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Text(
                          AppFormatters.currency(lineTotal),
                          key: ValueKey('${item.id}-${item.quantity}'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.brandPrimaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.unitPriceLabel.isEmpty ? AppFormatters.currency(item.unitPrice) : item.unitPriceLabel} c/u',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      TextButton(
                        onPressed: isMutating ? null : onRemove,
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ],
              ),
              if (item.variantName != null && item.variantName!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.variantName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (item.modifierSelections.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.modifierSelections
                      .map(
                        (selection) => _BagModifierChip(selection: selection),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BagModifierChip extends StatelessWidget {
  const _BagModifierChip({required this.selection});

  final BagModifierSelection selection;

  @override
  Widget build(BuildContext context) {
    final isAdded = selection.priceDelta > 0;
    final optionLabel = selection.modifierOptionName.trim();
    final normalizedOptionLabel = optionLabel.toLowerCase();
    final label = isAdded
        ? 'Agregado: $optionLabel'
        : normalizedOptionLabel.startsWith('sin ')
            ? optionLabel
            : 'Excluido: $optionLabel';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isAdded
            ? AppColors.brandPrimary.withValues(alpha: 0.10)
            : AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isAdded ? AppColors.brandPrimary : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isAdded ? AppColors.brandPrimaryDark : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
