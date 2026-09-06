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
import '../../storefront/domain/storefront_payload.dart';
import '../../storefront/infrastructure/storefront_api.dart';

class BagScreen extends StatefulWidget {
  const BagScreen({
    super.key,
    required this.bagApi,
    required this.bagCountController,
    required this.authSession,
    required this.storefrontApi,
    required this.tenantSlug,
    required this.branchId,
  });

  final BagApi bagApi;
  final BagCountController bagCountController;
  final AuthSession authSession;
  final StorefrontApi storefrontApi;
  final String tenantSlug;
  final String branchId;

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  late final BagController _controller;
  BagLoadResult? _result;
  StorefrontBranch? _branch;
  Object? _loadError;
  bool _loading = true;
  bool _clearing = false;
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
      final results = await Future.wait<Object>([
        _controller.load(
          tenantSlug: widget.tenantSlug,
          branchId: widget.branchId,
        ),
        widget.storefrontApi.fetchStorefront(
          tenantSlug: widget.tenantSlug,
          branchId: widget.branchId,
        ),
      ]);
      final result = results[0] as BagLoadResult;
      final storefront = results[1] as StorefrontPayload;

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
        _branch = storefront.storefront.activeBranch;
        _loading = false;
      });
      widget.bagCountController.setCountForContext(
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        count:
            result.payload?.items.fold<int>(
              0,
              (sum, item) => sum + item.quantity,
            ) ??
            0,
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
      final results = await Future.wait<Object>([
        _controller.load(
          tenantSlug: widget.tenantSlug,
          branchId: widget.branchId,
        ),
        widget.storefrontApi.fetchStorefront(
          tenantSlug: widget.tenantSlug,
          branchId: widget.branchId,
        ),
      ]);
      final result = results[0] as BagLoadResult;
      final storefront = results[1] as StorefrontPayload;

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
        _branch = storefront.storefront.activeBranch;
      });
      widget.bagCountController.setCountForContext(
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        count:
            _result?.payload?.items.fold<int>(
              0,
              (sum, item) => sum + item.quantity,
            ) ??
            0,
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

    final refreshedById = {for (final item in refreshedItems) item.id: item};
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

  /// Rolls the optimistic bag state back to [previousPayload] and tells the
  /// customer why. Shared by the network-failure path and the backend
  /// "ok:false" path (out of stock, branch just closed, ...).
  void _restoreBag(
    BagLoadResult currentResult,
    BagPayload previousPayload, {
    String? message,
  }) {
    setState(() {
      _result = BagLoadResult(
        status: currentResult.status,
        payload: previousPayload,
      );
    });
    widget.bagCountController.setCountForContext(
      tenantSlug: widget.tenantSlug,
      branchId: widget.branchId,
      count: previousPayload.items.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message != null && message.trim().isNotEmpty
              ? message
              : 'No se pudo actualizar la bolsa de compra.',
        ),
      ),
    );
  }

  Future<void> _clearBag() async {
    final currentResult = _result;
    final currentPayload = currentResult?.payload;
    if (currentResult == null ||
        currentPayload == null ||
        currentPayload.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vaciar la bolsa'),
        content: const Text(
          'Se quitaran todos los productos de esta sucursal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final accessToken = await widget.authSession.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        final back =
            '/storefront/${widget.tenantSlug}/bag?branchId=${widget.branchId}';
        context.push('/login?redirect=${Uri.encodeComponent(back)}');
      }
      return;
    }

    final previousPayload = currentPayload;
    setState(() {
      _clearing = true;
      _result = BagLoadResult(
        status: currentResult.status,
        payload: currentPayload.copyWith(items: const []),
      );
    });
    widget.bagCountController.setCountForContext(
      tenantSlug: widget.tenantSlug,
      branchId: widget.branchId,
      count: 0,
    );

    try {
      final result = await widget.bagApi.clearBag(
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        accessToken: accessToken,
      );
      if (!mounted) {
        return;
      }
      if (!result.ok) {
        _restoreBag(currentResult, previousPayload, message: result.error);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _restoreBag(
        currentResult,
        previousPayload,
        message: 'No se pudo vaciar la bolsa: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _clearing = false;
        });
      }
    }
  }

  Future<void> _runBagMutation({
    required String itemId,
    required BagPayload Function(BagPayload payload) optimisticUpdate,
    required Future<BagMutationResult> Function(String accessToken) action,
  }) async {
    final branch = _branch;
    if (branch != null && !branch.acceptingOrders) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              branch.closureLabel?.trim().isNotEmpty == true
                  ? branch.closureLabel!
                  : 'Esta sucursal no esta aceptando pedidos ahora mismo.',
            ),
          ),
        );
      }
      return;
    }

    final accessToken = await widget.authSession.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        final back =
            '/storefront/${widget.tenantSlug}/bag?branchId=${widget.branchId}';
        context.push('/login?redirect=${Uri.encodeComponent(back)}');
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
      count:
          _result?.payload?.items.fold<int>(
            0,
            (sum, item) => sum + item.quantity,
          ) ??
          0,
    );

    try {
      final result = await action(accessToken);
      if (!mounted) {
        return;
      }

      if (!result.ok) {
        _restoreBag(currentResult, previousPayload, message: result.error);
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

      _restoreBag(
        currentResult,
        previousPayload,
        message: 'No se pudo actualizar la bolsa de compra: $error',
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

    final hasItems = payload != null && !payload.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bolsa de compra'),
        actions: [
          if (hasItems)
            TextButton(
              onPressed: _clearing ? null : _clearBag,
              child: Text(_clearing ? 'Vaciando...' : 'Vaciar'),
            ),
        ],
      ),
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
          : _CheckoutBottomBar(payload: payload, branch: _branch),
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
      branch: _branch,
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
    required this.branch,
    required this.mutatingItemId,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  final BagPayload payload;
  final StorefrontBranch? branch;
  final String? mutatingItemId;
  final Future<void> Function(BagItem item) onDecrement;
  final Future<void> Function(BagItem item) onIncrement;
  final Future<void> Function(BagItem item) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canOrder = branch?.acceptingOrders ?? true;

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
              if (!canOrder) ...[
                const SizedBox(height: 12),
                _BranchOrderingClosedBanner(branch: branch!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...payload.items.map(
          (item) => _BagItemCard(
            item: item,
            canEdit: canOrder,
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
  const _CheckoutBottomBar({required this.payload, required this.branch});

  final BagPayload payload;
  final StorefrontBranch? branch;

  @override
  Widget build(BuildContext context) {
    final canCheckout = branch?.acceptingOrders ?? true;

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
            onPressed: !canCheckout
                ? null
                : () => context.push(
                    '/storefront/${payload.items.first.tenantSlug}/checkout?branchId=${payload.items.first.branchId}',
                  ),
            child: Text(canCheckout ? 'Ir a checkout' : 'Sucursal cerrada'),
          ),
        ),
      ),
    );
  }
}

class _BagRequiresLogin extends StatelessWidget {
  const _BagRequiresLogin({required this.tenantSlug, required this.branchId});

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
                'Tu sesion expiro o aun no has iniciado sesion. Vuelve a iniciar sesion para ver y modificar tu bolsa.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push(
                  '/login?redirect=${Uri.encodeComponent('/storefront/$tenantSlug/bag?branchId=$branchId')}',
                ),
                child: const Text('Iniciar sesion'),
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

class _BagItemCard extends StatelessWidget {
  const _BagItemCard({
    required this.item,
    required this.canEdit,
    required this.isMutating,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  final BagItem item;
  final bool canEdit;
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
                    onDecrement: canEdit ? onDecrement : null,
                    onIncrement: canEdit ? onIncrement : null,
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
                        onPressed: !canEdit || isMutating ? null : onRemove,
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ],
              ),
              if (item.variantName != null &&
                  item.variantName!.trim().isNotEmpty) ...[
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

class _BranchOrderingClosedBanner extends StatelessWidget {
  const _BranchOrderingClosedBanner({required this.branch});

  final StorefrontBranch branch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.closureLabel?.trim().isNotEmpty == true
                ? branch.closureLabel!
                : 'Esta sucursal no esta aceptando pedidos ahora mismo.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF8A5300),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (branch.nextTransitionLabel?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              branch.nextTransitionLabel!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8A5300),
              ),
            ),
          ],
        ],
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
