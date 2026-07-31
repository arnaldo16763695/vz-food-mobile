import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../bag/infrastructure/bag_api.dart';
import '../../../core/theme/app_colors.dart';
import '../application/storefront_controller.dart';
import '../domain/storefront_payload.dart';
import '../infrastructure/storefront_api.dart';

class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({
    super.key,
    required this.authSession,
    required this.bagApi,
    required this.storefrontApi,
    required this.tenantSlug,
    required this.branchId,
  });

  final AuthSession authSession;
  final BagApi bagApi;
  final StorefrontApi storefrontApi;
  final String tenantSlug;
  final String? branchId;

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  late final StorefrontController _controller;
  late Future<StorefrontPayload> _future;
  String? _addingProductId;

  @override
  void initState() {
    super.initState();
    _controller = StorefrontController(widget.storefrontApi);
    _future = _load();
  }

  Future<StorefrontPayload> _load() {
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

  Future<void> _addProduct(StorefrontProduct product) async {
    final activeBranchId = widget.branchId;
    if (activeBranchId == null || activeBranchId.isEmpty) {
      _showSnackBar('Selecciona una sucursal antes de agregar productos.');
      return;
    }

    if (product.requiresCustomization) {
      await _openConfigurator(product);
      return;
    }

    await _submitAddToBag(product: product);
  }

  Future<void> _openConfigurator(StorefrontProduct product) async {
    final configuration = await showModalBottomSheet<_ConfiguredProductResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProductConfiguratorSheet(product: product),
    );

    if (configuration == null) {
      return;
    }

    await _submitAddToBag(
      product: product,
      variantId: configuration.variantId,
      modifierSelections: configuration.modifierSelections,
    );
  }

  Future<void> _submitAddToBag({
    required StorefrontProduct product,
    String? variantId,
    List<Map<String, dynamic>> modifierSelections = const [],
  }) async {
    final activeBranchId = widget.branchId;
    if (activeBranchId == null || activeBranchId.isEmpty) {
      _showSnackBar('Selecciona una sucursal antes de agregar productos.');
      return;
    }

    final accessToken = await widget.authSession.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        context.push('/account');
      }
      return;
    }

    setState(() {
      _addingProductId = product.id;
    });

    try {
      await widget.bagApi.addItem(
        tenantSlug: widget.tenantSlug,
        branchId: activeBranchId,
        productId: product.id,
        productVariantId: variantId ?? product.defaultVariantId,
        modifierSelections: modifierSelections,
        accessToken: accessToken,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} agregado al bag.'),
          action: SnackBarAction(
            label: 'Ver bag',
            onPressed: () {
              context.push(
                '/storefront/${widget.tenantSlug}/bag?branchId=$activeBranchId',
              );
            },
          ),
        ),
      );
    } catch (error) {
      _showSnackBar('No se pudo agregar el producto: $error');
    } finally {
      if (mounted) {
        setState(() {
          _addingProductId = null;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Storefront')),
      body: SafeArea(
        child: FutureBuilder<StorefrontPayload>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _StorefrontError(
                error: snapshot.error,
                onRetry: _retry,
              );
            }

            final payload = snapshot.data;
            if (payload == null) {
              return const _StorefrontEmpty();
            }

            return _StorefrontView(
              addingProductId: _addingProductId,
              onAddProduct: _addProduct,
              payload: payload,
              tenantSlug: widget.tenantSlug,
            );
          },
        ),
      ),
    );
  }
}

class _StorefrontView extends StatelessWidget {
  const _StorefrontView({
    required this.addingProductId,
    required this.onAddProduct,
    required this.payload,
    required this.tenantSlug,
  });

  final String? addingProductId;
  final Future<void> Function(StorefrontProduct product) onAddProduct;
  final StorefrontPayload payload;
  final String tenantSlug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storefront = payload.storefront;
    final menuByCategory = storefront.menuByCategory;

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
                storefront.tenant.name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                storefront.activeBranch?.name ?? 'Sucursal sin seleccionar',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ETA ${storefront.etaMinutes} min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: storefront.activeBranch == null
                    ? null
                    : () {
                        context.push(
                          '/storefront/$tenantSlug/bag?branchId=${storefront.activeBranch!.id}',
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.brandPrimaryDark,
                ),
                child: const Text('Ver bag'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => context.push('/storefront/$tenantSlug/orders'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                ),
                child: const Text('Ver pedidos'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionCard(
          title: 'Sucursales',
          subtitle: 'El storefront puede cambiar segun la sucursal activa. Este selector prepara el flujo real de bag por branch.',
          child: storefront.branches.isEmpty
              ? const _EmptyBox(message: 'No hay sucursales disponibles.')
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: storefront.branches
                      .map(
                        (branch) => _BranchChip(
                          branch: branch,
                          isActive: branch.id == storefront.activeBranch?.id,
                          onTap: () {
                            context.go(
                              '/storefront/$tenantSlug?branchId=${branch.id}',
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Menu inicial',
          subtitle: 'Ya agrupamos por categoria para que la siguiente iteracion pueda conectar detalle de producto y bag sin rehacer esta pantalla.',
          child: storefront.hasMenu
              ? Column(
                  children: menuByCategory.entries
                      .map(
                        (entry) => _CategorySection(
                          addingProductId: addingProductId,
                          onAddProduct: onAddProduct,
                          title: entry.key,
                          products: entry.value,
                        ),
                      )
                      .toList(),
                )
              : const _EmptyBox(message: 'Esta sucursal no tiene productos visibles todavia.'),
        ),
      ],
    );
  }
}

class _StorefrontError extends StatelessWidget {
  const _StorefrontError({
    required this.error,
    required this.onRetry,
  });

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
              Text('No se pudo cargar storefront', style: theme.textTheme.titleLarge),
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

class _StorefrontEmpty extends StatelessWidget {
  const _StorefrontEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Storefront sin contenido.'));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: theme.textTheme.bodyMedium),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.branch,
    required this.isActive,
    required this.onTap,
  });

  final StorefrontBranch branch;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : AppColors.background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isActive ? AppColors.brandPrimary : AppColors.border,
          ),
        ),
        child: Text(
          branch.name,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isActive ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.addingProductId,
    required this.onAddProduct,
    required this.title,
    required this.products,
  });

  final String? addingProductId;
  final Future<void> Function(StorefrontProduct product) onAddProduct;
  final String title;
  final List<StorefrontProduct> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ...products.map(
            (product) => _ProductTile(
              product: product,
              isAdding: addingProductId == product.id,
              onAdd: () => onAddProduct(product),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.isAdding,
    required this.onAdd,
  });

  final StorefrontProduct product;
  final bool isAdding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(product.category, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Text(product.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              product.basePrice,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.brandPrimaryDark,
              ),
            ),
            const SizedBox(height: 12),
            if (product.requiresCustomization)
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: isAdding ? null : onAdd,
                  child: Text(isAdding ? 'Abriendo...' : 'Configurar'),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: isAdding ? null : onAdd,
                  child: Text(isAdding ? 'Agregando...' : 'Agregar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfiguredProductResult {
  const _ConfiguredProductResult({
    required this.variantId,
    required this.modifierSelections,
  });

  final String? variantId;
  final List<Map<String, dynamic>> modifierSelections;
}

class _ProductConfiguratorSheet extends StatefulWidget {
  const _ProductConfiguratorSheet({required this.product});

  final StorefrontProduct product;

  @override
  State<_ProductConfiguratorSheet> createState() =>
      _ProductConfiguratorSheetState();
}

class _ProductConfiguratorSheetState extends State<_ProductConfiguratorSheet> {
  late String? _selectedVariantId;
  final Map<String, Set<String>> _selectedOptionsByGroup = {};
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _selectedVariantId = widget.product.defaultVariantId;
  }

  void _toggleOption(
    StorefrontModifierGroup group,
    StorefrontModifierOption option,
    bool selected,
  ) {
    final current = {...?_selectedOptionsByGroup[group.id]};

    if (group.isSingleSelection) {
      current
        ..clear()
        ..add(option.id);
    } else {
      if (selected) {
        if (group.maxSelect > 0 && current.length >= group.maxSelect) {
          return;
        }
        current.add(option.id);
      } else {
        current.remove(option.id);
      }
    }

    setState(() {
      _selectedOptionsByGroup[group.id] = current;
      _validationMessage = null;
    });
  }

  void _submit() {
    for (final group in widget.product.modifierGroups) {
      final selectedCount = _selectedOptionsByGroup[group.id]?.length ?? 0;
      if (selectedCount < group.minSelect) {
        setState(() {
          _validationMessage = 'Completa la seleccion requerida en ${group.name}.';
        });
        return;
      }
    }

    final selections = <Map<String, dynamic>>[];
    for (final group in widget.product.modifierGroups) {
      final selectedIds = _selectedOptionsByGroup[group.id] ?? const <String>{};
      for (final option in group.options.where((option) => selectedIds.contains(option.id))) {
        selections.add({
          'modifierGroupId': group.id,
          'modifierGroupName': group.name,
          'modifierOptionId': option.id,
          'modifierOptionName': option.name,
          'priceDelta': option.priceDelta,
        });
      }
    }

    Navigator.of(context).pop(
      _ConfiguredProductResult(
        variantId: _selectedVariantId,
        modifierSelections: selections,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(product.description, style: theme.textTheme.bodyMedium),
              if (product.variants.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Variante', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                ...product.variants.map(
                  (variant) => _SelectableOptionTile(
                    title: variant.name,
                    subtitle: variant.basePrice,
                    selected: _selectedVariantId == variant.id,
                    onTap: () {
                      setState(() {
                        _selectedVariantId = variant.id;
                      });
                    },
                  ),
                ),
              ],
              ...product.modifierGroups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        group.minSelect > 0
                            ? 'Seleccion requerida'
                            : 'Opcional',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      ...group.options.map(
                        (option) {
                          final selected =
                              _selectedOptionsByGroup[group.id]?.contains(option.id) ?? false;

                          if (group.isSingleSelection) {
                            return _SelectableOptionTile(
                              title: option.name,
                              subtitle: option.priceDeltaLabel,
                              selected:
                                  _selectedOptionsByGroup[group.id]?.firstOrNull == option.id,
                              onTap: () {
                                _toggleOption(group, option, true);
                              },
                            );
                          }

                          return CheckboxListTile(
                            value: selected,
                            onChanged: (value) {
                              _toggleOption(group, option, value ?? false);
                            },
                            title: Text(option.name),
                            subtitle: Text(option.priceDeltaLabel),
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (_validationMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _validationMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Agregar al bag'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Set<String> {
  String? get firstOrNull => isEmpty ? null : first;
}

class _SelectableOptionTile extends StatelessWidget {
  const _SelectableOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandPrimary.withValues(alpha: 0.12) : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.brandPrimary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? AppColors.brandPrimary : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
