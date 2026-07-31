import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../application/bag_controller.dart';
import '../application/bag_load_result.dart';
import '../domain/bag_payload.dart';
import '../infrastructure/bag_api.dart';

class BagScreen extends StatefulWidget {
  const BagScreen({
    super.key,
    required this.bagApi,
    required this.authSession,
    required this.tenantSlug,
    required this.branchId,
  });

  final BagApi bagApi;
  final AuthSession authSession;
  final String tenantSlug;
  final String branchId;

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  late final BagController _controller;
  late Future<BagLoadResult> _future;
  String? _mutatingItemId;

  @override
  void initState() {
    super.initState();
    _controller = BagController(widget.bagApi, widget.authSession);
    _future = _load();
  }

  Future<BagLoadResult> _load() {
    return _controller.load(
      tenantSlug: widget.tenantSlug,
      branchId: widget.branchId,
    );
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _incrementItem(BagItem item) async {
    await _runBagMutation(
      itemId: item.id,
      action: (accessToken) {
        return widget.bagApi.replaceItem(
          tenantSlug: widget.tenantSlug,
          bagItemId: item.id,
          accessToken: accessToken,
          branchId: widget.branchId,
          productId: item.productId,
          quantity: item.quantity + 1,
          productVariantId: item.productVariantId,
          modifierSelections: item.modifierSelections
              .map((selection) => selection.toRequestJson())
              .toList(growable: false),
        );
      },
    );
  }

  Future<void> _decrementItem(BagItem item) async {
    await _runBagMutation(
      itemId: item.id,
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
    required Future<void> Function(String accessToken) action,
  }) async {
    final accessToken = await widget.authSession.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        context.push('/account');
      }
      return;
    }

    setState(() {
      _mutatingItemId = itemId;
    });

    try {
      await action(accessToken);
      if (!mounted) {
        return;
      }

      setState(() {
        _future = _load();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el bag: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _mutatingItemId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bag')),
      body: SafeArea(
        child: FutureBuilder<BagLoadResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _BagError(error: snapshot.error, onRetry: _retry);
            }

            final result = snapshot.data;
            if (result == null) {
              return const _BagEmpty();
            }

            if (result.requiresLogin) {
              return const _BagRequiresLogin();
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
          },
        ),
      ),
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
              Text('Tu bag', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Esta primera version valida el contrato autenticado del bag antes de agregar mutaciones de cantidad y checkout.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push(
                  '/storefront/${payload.items.first.tenantSlug}/checkout?branchId=${payload.items.first.branchId}',
                ),
                child: const Text('Ir a checkout'),
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

class _BagRequiresLogin extends StatelessWidget {
  const _BagRequiresLogin();

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
                'Bag es una superficie autenticada. La pantalla ya esta lista para el endpoint real, pero falta conectar Supabase Auth para obtener el Bearer token del cliente.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push('/account'),
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
            'El bag esta vacio para esta sucursal.',
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
              Text('No se pudo cargar bag', style: theme.textTheme.titleLarge),
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
                  Row(
                    children: [
                      IconButton(
                        onPressed: isMutating ? null : onDecrement,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        'x${item.quantity}',
                        style: theme.textTheme.bodyLarge,
                      ),
                      IconButton(
                        onPressed: isMutating ? null : onIncrement,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.unitPriceLabel,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.brandPrimaryDark,
                        ),
                      ),
                      TextButton(
                        onPressed: isMutating ? null : onRemove,
                        child: Text(isMutating ? 'Actualizando...' : 'Eliminar'),
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
            ],
          ),
        ),
      ),
    );
  }
}
