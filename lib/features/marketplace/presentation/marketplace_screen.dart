import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/storefront_link.dart';
import '../../../core/theme/app_colors.dart';
import '../application/marketplace_controller.dart';
import '../domain/brand_summary.dart';
import '../domain/brands_payload.dart';
import '../infrastructure/brands_api.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key, required this.brandsApi});

  final BrandsApi brandsApi;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late final MarketplaceController _controller;
  late Future<BrandsPayload> _brandsFuture;

  @override
  void initState() {
    super.initState();
    _controller = MarketplaceController(widget.brandsApi);
    _brandsFuture = _controller.load();
  }

  void _retry() {
    setState(() {
      _brandsFuture = _controller.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      body: SafeArea(
        child: FutureBuilder<BrandsPayload>(
          future: _brandsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _MarketplaceLoading();
            }

            if (snapshot.hasError) {
              return _MarketplaceError(error: snapshot.error, onRetry: _retry);
            }

            final payload = snapshot.data;
            if (payload == null || payload.isEmpty) {
              return const _MarketplaceEmpty();
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marcas disponibles',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Esta vista agrupa el discovery publico y prepara el salto futuro hacia storefront por tenant y sucursal.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...payload.brands.map(
                  (brand) => _BrandCard(
                    brand: brand,
                    onTap: () {
                      final link = StorefrontLink.tryParse(
                        brand.storefrontHref,
                      );
                      if (link != null) {
                        context.push(link.routeLocation);
                      }
                    },
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

class _MarketplaceLoading extends StatelessWidget {
  const _MarketplaceLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _MarketplaceError extends StatelessWidget {
  const _MarketplaceError({required this.error, required this.onRetry});

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
                'No se pudo cargar marketplace',
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

class _MarketplaceEmpty extends StatelessWidget {
  const _MarketplaceEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No hay marcas publicas disponibles todavia.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.brand, required this.onTap});

  final BrandSummary brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(brand.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(brand.cuisine, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Text(brand.headline, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BrandMetaChip(label: '${brand.etaMinutes} min'),
                    _BrandMetaChip(label: brand.nearestBranch),
                    _BrandMetaChip(
                      label: '${brand.activeBranchCount} sucursales',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Abrir storefront',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.brandPrimaryDark,
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

class _BrandMetaChip extends StatelessWidget {
  const _BrandMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}
