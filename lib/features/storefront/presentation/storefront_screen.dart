// ignore_for_file: unused_element, unused_field

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/customer_footer_nav.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../bag/application/bag_count_controller.dart';
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
    required this.bagCountController,
    required this.storefrontApi,
    required this.tenantSlug,
    required this.branchId,
  });

  final AuthSession authSession;
  final BagApi bagApi;
  final BagCountController bagCountController;
  final StorefrontApi storefrontApi;
  final String tenantSlug;
  final String? branchId;

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  late final StorefrontController _controller;
  StorefrontPayload? _payload;
  Object? _loadError;
  bool _loading = true;
  DateTime? _loadStartedAt;
  String? _addingProductId;

  @override
  void initState() {
    super.initState();
    _controller = StorefrontController(widget.storefrontApi);
    _load();
  }

  @override
  void didUpdateWidget(covariant StorefrontScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final tenantChanged = oldWidget.tenantSlug != widget.tenantSlug;
    final branchChanged = oldWidget.branchId != widget.branchId;

    if (tenantChanged || branchChanged) {
      setState(() {
        _addingProductId = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
      _loadStartedAt = DateTime.now();
    });

    try {
      debugPrint(
        'Storefront load start tenant=${widget.tenantSlug} branch=${widget.branchId}',
      );

      final payload = await _controller
          .load(tenantSlug: widget.tenantSlug, branchId: widget.branchId)
          .timeout(const Duration(seconds: 20));

      debugPrint(
        'Storefront load success tenant=${widget.tenantSlug} branch=${widget.branchId} menu=${payload.storefront.menu.length} branches=${payload.storefront.branches.length}',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _payload = payload;
        _loading = false;
      });
    } catch (error) {
      debugPrint(
        'Storefront load error tenant=${widget.tenantSlug} branch=${widget.branchId} error=$error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  void _retry() {
    _load();
  }

  Future<List<StorefrontProduct>> _searchProducts({
    required String query,
    String? branchId,
  }) {
    return _controller.searchProducts(
      tenantSlug: widget.tenantSlug,
      branchId: branchId,
      query: query,
    );
  }

  Future<void> _addProduct(StorefrontProduct product) async {
    final activeBranchId = widget.branchId;
    final activeBranch = _payload?.storefront.activeBranch;
    if (activeBranchId == null || activeBranchId.isEmpty) {
      _showSnackBar('Selecciona una sucursal antes de agregar productos.');
      return;
    }

    if (activeBranch != null && !activeBranch.acceptingOrders) {
      _showSnackBar(
        activeBranch.closureLabel?.trim().isNotEmpty == true
            ? activeBranch.closureLabel!
            : 'Esta sucursal no esta aceptando pedidos ahora mismo.',
      );
      return;
    }

    await _openConfigurator(product);
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
      quantity: configuration.quantity,
    );
  }

  Future<void> _submitAddToBag({
    required StorefrontProduct product,
    String? variantId,
    List<Map<String, dynamic>> modifierSelections = const [],
    int quantity = 1,
  }) async {
    final activeBranchId = widget.branchId;
    final activeBranch = _payload?.storefront.activeBranch;
    if (activeBranchId == null || activeBranchId.isEmpty) {
      _showSnackBar('Selecciona una sucursal antes de agregar productos.');
      return;
    }

    if (activeBranch != null && !activeBranch.acceptingOrders) {
      _showSnackBar(
        activeBranch.closureLabel?.trim().isNotEmpty == true
            ? activeBranch.closureLabel!
            : 'Esta sucursal no esta aceptando pedidos ahora mismo.',
      );
      return;
    }

    final accessToken = await widget.authSession.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        final activeBranchId = widget.branchId ?? '';
        final back =
            '/storefront/${widget.tenantSlug}${activeBranchId.isEmpty ? '' : '?branchId=$activeBranchId'}';
        context.push('/login?redirect=${Uri.encodeComponent(back)}');
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
        quantity: quantity,
        productVariantId: variantId ?? product.defaultVariantId,
        modifierSelections: modifierSelections,
        accessToken: accessToken,
      );

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${product.name} agregado a la bolsa de compra.'),
          duration: const Duration(seconds: 5),
        ),
      );
      widget.bagCountController.setCountForContext(
        tenantSlug: widget.tenantSlug,
        branchId: activeBranchId,
        count: (widget.bagCountController.count ?? 0) + quantity,
      );
      Future<void>.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          messenger.hideCurrentSnackBar();
        }
      });
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

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmReturnToMarketplace() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Volver al marketplace'),
          content: const Text(
            'Si sales del storefront volveras al marketplace. Quieres continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Volver'),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true && mounted) {
      context.go('/marketplace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _confirmReturnToMarketplace,
        ),
        title: const Text('Storefront'),
      ),
      bottomNavigationBar: CustomerFooterNav(
        currentTab: CustomerFooterTab.home,
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        authSession: widget.authSession,
        bagApi: widget.bagApi,
        bagCountController: widget.bagCountController,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Cargando storefront...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_loadStartedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Tenant: ${widget.tenantSlug}${widget.branchId == null || widget.branchId!.isEmpty ? '' : ' · Branch: ${widget.branchId}'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
    }

    if (_loadError != null) {
      return _StorefrontError(error: _loadError, onRetry: _retry);
    }

    final payload = _payload;
    if (payload == null) {
      return const _StorefrontEmpty();
    }

    return _StorefrontView(
      addingProductId: _addingProductId,
      onAddProduct: _addProduct,
      onSearchProducts: _searchProducts,
      payload: payload,
      tenantSlug: widget.tenantSlug,
    );
  }
}

class _StorefrontView extends StatefulWidget {
  const _StorefrontView({
    required this.addingProductId,
    required this.onAddProduct,
    required this.onSearchProducts,
    required this.payload,
    required this.tenantSlug,
  });

  final String? addingProductId;
  final Future<void> Function(StorefrontProduct product) onAddProduct;
  final Future<List<StorefrontProduct>> Function({
    required String query,
    String? branchId,
  })
  onSearchProducts;
  final StorefrontPayload payload;
  final String tenantSlug;

  @override
  State<_StorefrontView> createState() => _StorefrontViewState();
}

class _StorefrontViewState extends State<_StorefrontView> {
  String _searchQuery = '';
  List<StorefrontProduct>? _searchResults;
  Object? _searchError;
  Timer? _searchDebounce;
  int _searchRequestId = 0;
  bool _isSearching = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StorefrontView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final previousActiveBranchId =
        oldWidget.payload.storefront.activeBranch?.id;
    final nextActiveBranchId = widget.payload.storefront.activeBranch?.id;
    final tenantChanged =
        oldWidget.payload.storefront.tenant.slug !=
        widget.payload.storefront.tenant.slug;
    final branchChanged = previousActiveBranchId != nextActiveBranchId;

    if (tenantChanged || branchChanged) {
      _searchQuery = '';
      _searchResults = null;
      _searchError = null;
      _isSearching = false;
      _searchRequestId += 1;
      _searchDebounce?.cancel();
    }
  }

  void _handleSearchChanged(String value, String? branchId) {
    _searchDebounce?.cancel();

    setState(() {
      _searchQuery = value;
      _searchError = null;
      if (value.trim().isEmpty) {
        _searchResults = null;
        _isSearching = false;
      } else {
        _isSearching = true;
      }
    });

    final normalizedQuery = value.trim();
    if (normalizedQuery.isEmpty) {
      _searchRequestId += 1;
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final requestId = ++_searchRequestId;

      try {
        final results = await widget.onSearchProducts(
          query: normalizedQuery,
          branchId: branchId,
        );

        if (!mounted || requestId != _searchRequestId) {
          return;
        }

        setState(() {
          _searchResults = results;
          _searchError = null;
          _isSearching = false;
        });
      } catch (error) {
        if (!mounted || requestId != _searchRequestId) {
          return;
        }

        setState(() {
          _searchError = error;
          _searchResults = const [];
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storefront = widget.payload.storefront;
    final activeBranch = storefront.activeBranch;
    final activeBranchId = storefront.activeBranch?.id;
    final hasMultipleBranches = storefront.branches.length > 1;
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final visibleProducts = normalizedQuery.isEmpty
        ? storefront.menu
        : (_searchResults ?? const <StorefrontProduct>[]);
    final selectedBranchId =
        storefront.branches.any((branch) => branch.id == activeBranchId)
        ? activeBranchId
        : null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _StorefrontHero(storefront: storefront),
        const SizedBox(height: 20),
        if (activeBranch != null && !activeBranch.acceptingOrders) ...[
          _BranchOrderingClosedCallout(branch: activeBranch),
          const SizedBox(height: 16),
        ],
        if (storefront.hasMenu)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${storefront.menu.length} productos disponibles',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (hasMultipleBranches) ...[
          _SectionCard(
            title: 'Sucursales',
            subtitle:
                'El storefront puede cambiar segun la sucursal activa. Este selector prepara el flujo real de la bolsa de compra por sucursal.',
            child: _BranchSelect(
              branches: storefront.branches,
              selectedBranchId: selectedBranchId,
              onChanged: (branchId) {
                if (branchId == null || branchId.isEmpty) {
                  return;
                }
                context.go(
                  '/storefront/${widget.tenantSlug}?branchId=$branchId',
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProductSearchField(
                initialValue: _searchQuery,
                onChanged: (value) =>
                    _handleSearchChanged(value, activeBranchId),
              ),
              const SizedBox(height: 16),
              if (normalizedQuery.isNotEmpty && !_isSearching) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'Resultados para "${_searchQuery.trim()}"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (!storefront.hasMenu)
                const _EmptyBox(
                  message: 'Esta sucursal no tiene productos visibles todavia.',
                )
              else if (_isSearching)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_searchError != null)
                const _EmptyBox(
                  message:
                      'No se pudo completar la busqueda. Intenta de nuevo.',
                )
              else if (visibleProducts.isEmpty)
                const _EmptyBox(
                  message: 'No encontramos productos con esa busqueda.',
                )
              else
                _TwoColumnProductGrid(
                  products: visibleProducts,
                  addingProductId: widget.addingProductId,
                  canAddToBag: activeBranch?.acceptingOrders ?? false,
                  onAddProduct: widget.onAddProduct,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StorefrontHero extends StatelessWidget {
  const _StorefrontHero({required this.storefront});

  final Storefront storefront;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeBranchHero = storefront.activeBranch?.heroImageUrl?.trim();
    final tenantHero = storefront.tenant.heroImageUrl?.trim();
    final heroImageUrl = activeBranchHero != null && activeBranchHero.isNotEmpty
        ? activeBranchHero
        : tenantHero;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: heroImageUrl != null && heroImageUrl.isNotEmpty
                  ? Image.network(
                      heroImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const _StorefrontHeroFallback();
                      },
                    )
                  : const _StorefrontHeroFallback(),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33147563), Color(0xE6147563)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        storefront.activeBranch?.name ??
                            'Sucursal sin seleccionar',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      storefront.tenant.name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explora el menu y agrega productos rapido desde el catalogo.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xE6FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroStatChip(
                            icon: Icons.schedule_rounded,
                            label: '${storefront.etaMinutes} min',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeroStatChip(
                            icon: Icons.grid_view_rounded,
                            label:
                                '${storefront.menuByCategory.length} categorias',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorefrontHeroFallback extends StatelessWidget {
  const _StorefrontHeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandPrimaryDark,
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_rounded,
        color: Color(0x66FFFFFF),
        size: 56,
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x21FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorefrontError extends StatelessWidget {
  const _StorefrontError({required this.error, required this.onRetry});

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
                'No se pudo cargar storefront',
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

class _StorefrontEmpty extends StatelessWidget {
  const _StorefrontEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Storefront sin contenido.'));
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({this.title, this.subtitle, required this.child});

  final String? title;
  final String? subtitle;
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
            if (title != null && title!.isNotEmpty) ...[
              Text(title!, style: theme.textTheme.titleLarge),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _BranchSelect extends StatelessWidget {
  const _BranchSelect({
    required this.branches,
    required this.selectedBranchId,
    required this.onChanged,
  });

  final List<StorefrontBranch> branches;
  final String? selectedBranchId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    StorefrontBranch? selectedBranch;
    for (final branch in branches) {
      if (branch.id == selectedBranchId) {
        selectedBranch = branch;
        break;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final value = await showModalBottomSheet<String>(
          context: context,
          builder: (context) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: branches
                    .map(
                      (branch) => ListTile(
                        title: Text(branch.name),
                        trailing: branch.id == selectedBranchId
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => Navigator.of(context).pop(branch.id),
                      ),
                    )
                    .toList(growable: false),
              ),
            );
          },
        );

        onChanged(value);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sucursal activa', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    selectedBranch?.name ?? 'Seleccionar sucursal',
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
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

class _ProductSearchField extends StatefulWidget {
  const _ProductSearchField({
    required this.initialValue,
    required this.onChanged,
  });

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends State<_ProductSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant _ProductSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar productos',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: AppColors.brandPrimary),
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
          _TwoColumnProductGrid(
            products: products,
            addingProductId: addingProductId,
            onAddProduct: onAddProduct,
          ),
        ],
      ),
    );
  }
}

class _TwoColumnProductGrid extends StatelessWidget {
  const _TwoColumnProductGrid({
    required this.products,
    required this.addingProductId,
    this.canAddToBag = true,
    required this.onAddProduct,
  });

  final List<StorefrontProduct> products;
  final String? addingProductId;
  final bool canAddToBag;
  final Future<void> Function(StorefrontProduct product) onAddProduct;

  @override
  Widget build(BuildContext context) {
    const spacing = 14.0;
    final rows = <Widget>[];

    for (var index = 0; index < products.length; index += 2) {
      final leftProduct = products[index];
      final rightProduct = index + 1 < products.length
          ? products[index + 1]
          : null;

      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ProductTile(
                  product: leftProduct,
                  isAdding: addingProductId == leftProduct.id,
                  canAddToBag: canAddToBag,
                  onAdd: () => onAddProduct(leftProduct),
                ),
              ),
              const SizedBox(width: spacing),
              Expanded(
                child: rightProduct == null
                    ? const SizedBox.shrink()
                    : _ProductTile(
                        product: rightProduct,
                        isAdding: addingProductId == rightProduct.id,
                        canAddToBag: canAddToBag,
                        onAdd: () => onAddProduct(rightProduct),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index != rows.length - 1) const SizedBox(height: spacing),
        ],
      ],
    );
  }
}

class _SimpleProductCard extends StatelessWidget {
  const _SimpleProductCard({
    required this.product,
    required this.addingProductId,
    required this.onAddProduct,
  });

  final StorefrontProduct product;
  final String? addingProductId;
  final Future<void> Function(StorefrontProduct product) onAddProduct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdding = addingProductId == product.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            if (product.description.trim().isNotEmpty)
              Text(product.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            Text(
              product.basePrice,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.brandPrimaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: isAdding ? null : () => onAddProduct(product),
                child: Text(isAdding ? 'Agregando...' : 'Agregar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.isAdding,
    required this.canAddToBag,
    required this.onAdd,
  });

  final StorefrontProduct product;
  final bool isAdding;
  final bool canAddToBag;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedImageUrl = product.imageUrl?.trim();
    final hasImage =
        normalizedImageUrl != null && normalizedImageUrl.isNotEmpty;
    final statusLabel = product.requiresCustomization
        ? 'Personalizable'
        : 'Listo';

    return Padding(
      padding: EdgeInsets.zero,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 16,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      hasImage
                          ? Image.network(
                              normalizedImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const _ProductImagePlaceholder();
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) {
                                      return child;
                                    }

                                    return const _ProductImagePlaceholder();
                                  },
                            )
                          : const _ProductImagePlaceholder(),
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x05000000), Color(0x36000000)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _ModernBadge(
                          label: statusLabel,
                          isAccent: product.requiresCustomization,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6F3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        product.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 15,
                        height: 1.15,
                      ),
                    ),
                    if (product.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        product.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      product.basePrice,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.brandPrimaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: !canAddToBag || isAdding ? null : onAdd,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary.withValues(
                            alpha: 0.14,
                          ),
                          foregroundColor: AppColors.brandPrimaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAdding
                                  ? Icons.hourglass_top_rounded
                                  : Icons.add_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              !canAddToBag
                                  ? 'Sucursal cerrada'
                                  : (isAdding ? 'Agregando' : 'Agregar'),
                            ),
                          ],
                        ),
                      ),
                    ),
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

class _BranchOrderingClosedCallout extends StatelessWidget {
  const _BranchOrderingClosedCallout({required this.branch});

  final StorefrontBranch branch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF8A5300),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (branch.nextTransitionLabel?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              branch.nextTransitionLabel!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8A5300),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModernBadge extends StatelessWidget {
  const _ModernBadge({required this.label, required this.isAccent});

  final String label;
  final bool isAccent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isAccent ? AppColors.accentWarm : Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected ? AppColors.brandPrimaryDark : AppColors.background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7EFEB),
      alignment: Alignment.center,
      child: const Icon(
        Icons.fastfood_rounded,
        size: 44,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _ProductMetaChip extends StatelessWidget {
  const _ProductMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}

class _ComboContents extends StatelessWidget {
  const _ComboContents({required this.components});

  final List<StorefrontComboComponent> components;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Incluye',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...components.map(
            (component) => Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• ${component.label}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfiguredProductResult {
  const _ConfiguredProductResult({
    required this.variantId,
    required this.modifierSelections,
    required this.quantity,
  });

  final String? variantId;
  final List<Map<String, dynamic>> modifierSelections;
  final int quantity;
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
  int _quantity = 1;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _selectedVariantId = widget.product.defaultVariantId;
    for (final group in widget.product.modifierGroups) {
      final defaultSelectedIds = group.options
          .where((option) => option.defaultSelected)
          .map((option) => option.id);

      final initialSelection = group.isSingleSelection
          ? defaultSelectedIds.take(1).toSet()
          : defaultSelectedIds.toSet();

      if (initialSelection.isNotEmpty) {
        _selectedOptionsByGroup[group.id] = initialSelection;
      }
    }
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
          _validationMessage =
              'Completa la seleccion requerida en ${group.name}.';
        });
        return;
      }
    }

    final selections = <Map<String, dynamic>>[];
    for (final group in widget.product.modifierGroups) {
      final selectedIds = _selectedOptionsByGroup[group.id] ?? const <String>{};
      for (final option in group.options) {
        final isSelected = selectedIds.contains(option.id);
        final wasSelectedByDefault = option.defaultSelected;

        if (wasSelectedByDefault && !isSelected) {
          selections.add({
            'modifierGroupId': group.id,
            'modifierGroupName': group.name,
            'modifierOptionId': option.id,
            'modifierOptionName': 'Sin ${option.name}',
            'priceDelta': 0,
          });
          continue;
        }

        if (!wasSelectedByDefault && isSelected) {
          selections.add({
            'modifierGroupId': group.id,
            'modifierGroupName': group.name,
            'modifierOptionId': option.id,
            'modifierOptionName': option.name,
            'priceDelta': option.priceDelta,
          });
        }
      }
    }

    Navigator.of(context).pop(
      _ConfiguredProductResult(
        variantId: _selectedVariantId,
        modifierSelections: selections,
        quantity: _quantity,
      ),
    );
  }

  String? _modifierStatusLabel(StorefrontModifierOption option, bool selected) {
    if (option.defaultSelected) {
      return selected ? null : 'Excluido';
    }

    if (!selected) {
      return null;
    }

    return option.priceDelta > 0 ? 'Agregado' : 'Incluido';
  }

  double get _unitPrice {
    final selectedVariant = widget.product.variants
        .cast<StorefrontProductVariant?>()
        .firstWhere(
          (variant) => variant?.id == _selectedVariantId,
          orElse: () => null,
        );
    final baseLabel = selectedVariant?.basePrice ?? widget.product.basePrice;
    final modifiersTotal = widget.product.modifierGroups.fold<double>(0, (
      total,
      group,
    ) {
      final selectedIds = _selectedOptionsByGroup[group.id] ?? const <String>{};
      return total +
          group.options
              .where((option) => selectedIds.contains(option.id))
              .fold<double>(0, (sum, option) => sum + option.priceDelta);
    });

    return _parseMoneyLabel(baseLabel) + modifiersTotal;
  }

  String get _totalLabel => AppFormatters.currency(_unitPrice * _quantity);

  String get _unitPriceLabel => AppFormatters.currency(_unitPrice);

  double _parseMoneyLabel(String value) {
    final normalized = value.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (normalized.isEmpty) {
      return 0;
    }

    final usesCommaAsDecimal =
        normalized.contains(',') && normalized.contains('.');
    final sanitized = usesCommaAsDecimal
        ? normalized.replaceAll(',', '')
        : normalized.replaceAll(',', '.');

    return double.tryParse(sanitized) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.product;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 28, 20, 20 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product.name, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text(product.description, style: theme.textTheme.bodyMedium),
              if (product.isCombo) ...[
                const SizedBox(height: 12),
                _ComboContents(components: product.comboComponents),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total', style: theme.textTheme.bodySmall),
                          const SizedBox(height: 4),
                          Text(
                            _totalLabel,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppColors.brandPrimaryDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$_unitPriceLabel c/u',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    QuantityStepper(
                      quantity: _quantity,
                      compact: true,
                      onDecrement: _quantity > 1
                          ? () {
                              setState(() {
                                _quantity -= 1;
                              });
                            }
                          : null,
                      onIncrement: () {
                        setState(() {
                          _quantity += 1;
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (product.variants.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('Tamaños', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
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
                  padding: const EdgeInsets.only(top: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 3),
                      Text(
                        group.minSelect > 0
                            ? 'Seleccion requerida'
                            : 'Opcional',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      ...group.options.map((option) {
                        final selected =
                            _selectedOptionsByGroup[group.id]?.contains(
                              option.id,
                            ) ??
                            false;

                        if (group.isSingleSelection) {
                          final isSelected =
                              _selectedOptionsByGroup[group.id]?.firstOrNull ==
                              option.id;
                          return _SelectableOptionTile(
                            title: option.name,
                            subtitle: option.priceDeltaLabel,
                            selected: isSelected,
                            selectedLabel: _modifierStatusLabel(
                              option,
                              isSelected,
                            ),
                            onTap: () {
                              _toggleOption(group, option, true);
                            },
                          );
                        }

                        return _SelectableOptionTile(
                          title: option.name,
                          subtitle: option.priceDeltaLabel,
                          selected: selected,
                          selectedLabel: _modifierStatusLabel(option, selected),
                          useCheckboxIcon: true,
                          onTap: () {
                            _toggleOption(group, option, !selected);
                          },
                        );
                      }),
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Agregar a la bolsa'),
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
    this.selectedLabel,
    this.useCheckboxIcon = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? selectedLabel;
  final bool useCheckboxIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandPrimary.withValues(alpha: 0.12)
                : AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.brandPrimary : AppColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                useCheckboxIcon
                    ? (selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded)
                    : (selected ? Icons.check_circle : Icons.circle_outlined),
                color: selected ? AppColors.brandPrimary : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (selectedLabel != null) ...[
                const SizedBox(width: 8),
                _ModifierStateTag(label: selectedLabel!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModifierStateTag extends StatelessWidget {
  const _ModifierStateTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.brandPrimaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
