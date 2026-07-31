import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/location/location_service.dart';
import '../../../core/navigation/storefront_link.dart';
import '../../../core/theme/app_colors.dart';
import '../application/home_controller.dart';
import '../application/home_load_result.dart';
import '../domain/home_payload.dart';
import '../infrastructure/home_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.config,
    required this.locationService,
    required this.homeApi,
  });

  final AppConfig config;
  final LocationService locationService;
  final HomeApi homeApi;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;
  late Future<HomeLoadResult> _homeFuture;

  @override
  void initState() {
    super.initState();
    _controller = HomeController(widget.homeApi, widget.locationService);
    _homeFuture = _controller.load();
  }

  void _retry() {
    setState(() {
      _homeFuture = _controller.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('VZ Food'),
        actions: [
          TextButton(
            onPressed: () => context.push('/account'),
            child: const Text('Cuenta'),
          ),
          TextButton(
            onPressed: () => context.push('/marketplace'),
            child: const Text('Marketplace'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Discovery customer-only listo para crecer',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Home ya consulta el backend real. El siguiente trabajo consiste en poblar estas secciones con contenido comercial y GPS real.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/marketplace'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.brandPrimaryDark,
                    ),
                    child: const Text('Explorar marketplace'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _EnvironmentCard(config: widget.config),
            const SizedBox(height: 20),
            FutureBuilder<HomeLoadResult>(
              future: _homeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const _HomeLoadingCard();
                }

                if (snapshot.hasError) {
                  return _HomeErrorCard(
                    error: snapshot.error,
                    onRetry: _retry,
                  );
                }

                final result = snapshot.data;
                final payload = result?.payload;
                if (result == null || payload == null || payload.isCompletelyEmpty) {
                  return _HomeEmptyCard(locationStatus: result?.locationStatus);
                }

                return _HomePayloadCard(
                  payload: payload,
                  locationStatus: result.locationStatus,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeLoadingCard extends StatelessWidget {
  const _HomeLoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cargando contenido inicial y consultando ubicacion si esta disponible...',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeErrorCard extends StatelessWidget {
  const _HomeErrorCard({
    required this.error,
    required this.onRetry,
  });

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No se pudo cargar Home', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'La app ya intenta usar el backend real. Este estado ayuda a validar conectividad y contrato antes de diseñar widgets definitivos.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              '$error',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmptyCard extends StatelessWidget {
  const _HomeEmptyCard({this.locationStatus});

  final LocationAccessStatus? locationStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Home sin contenido', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'El backend respondio correctamente, pero hoy las secciones comerciales aun estan vacias. Esta es una buena base para avanzar con banners, marcas destacadas y nearby por GPS.',
              style: theme.textTheme.bodyMedium,
            ),
            if (locationStatus != null &&
                locationStatus != LocationAccessStatus.granted) ...[
              const SizedBox(height: 12),
              Text(
                _locationHint(locationStatus!),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _locationHint(LocationAccessStatus status) {
    return switch (status) {
      LocationAccessStatus.denied =>
        'La ubicacion fue denegada, asi que nearby no puede calcular sucursales reales todavia.',
      LocationAccessStatus.deniedForever =>
        'La ubicacion esta bloqueada permanentemente para la app. Nearby necesita que se habilite desde ajustes.',
      LocationAccessStatus.disabled =>
        'Los servicios de ubicacion del dispositivo estan apagados.',
      LocationAccessStatus.unavailable =>
        'No se pudo obtener la ubicacion del dispositivo en este intento.',
      LocationAccessStatus.granted => '',
    };
  }
}

class _HomePayloadCard extends StatelessWidget {
  const _HomePayloadCard({
    required this.payload,
    required this.locationStatus,
  });

  final HomePayload payload;
  final LocationAccessStatus locationStatus;

  @override
  Widget build(BuildContext context) {
    if (payload.isCompletelyEmpty) {
      return const _HomeEmptyCard();
    }

    return Column(
      children: [
        if (locationStatus != LocationAccessStatus.granted) ...[
          _LocationStatusCard(status: locationStatus),
          const SizedBox(height: 16),
        ],
        _HomeSectionCard(
          title: 'Banners principales',
          subtitle: 'Promociones y accesos directos destacados para el inicio.',
          child: payload.heroBanners.isEmpty
              ? const _SectionEmptyMessage(
                  message: 'No hay banners activos todavia.',
                )
              : Column(
                  children: payload.heroBanners
                      .map((banner) => _HeroBannerTile(banner: banner))
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _HomeSectionCard(
          title: 'Marcas destacadas',
          subtitle: 'Descubrimiento editorial para llevar al cliente al storefront correcto.',
          child: payload.featuredBrands.isEmpty
              ? const _SectionEmptyMessage(
                  message: 'No hay marcas destacadas cargadas en este momento.',
                )
              : Column(
                  children: payload.featuredBrands
                      .map(
                        (brand) => _FeaturedBrandTile(
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
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 16),
        _HomeSectionCard(
          title: 'Sucursales cercanas',
          subtitle: 'Esta seccion debe poblarse con GPS real en la siguiente iteracion.',
          child: payload.nearbyBranches.isEmpty
              ? const _SectionEmptyMessage(
                  message: 'Aun no hay sucursales cercanas en home. Luego conectaremos GPS para enviar lat/lng.',
                )
              : Column(
                  children: payload.nearbyBranches
                      .map((branch) => _NearbyBranchTile(branch: branch))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({
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

class _SectionEmptyMessage extends StatelessWidget {
  const _SectionEmptyMessage({required this.message});

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

class _HeroBannerTile extends StatelessWidget {
  const _HeroBannerTile({required this.banner});

  final HomeHeroBanner banner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.brandPrimary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              banner.title,
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            if (banner.subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                banner.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              banner.ctaLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBrandTile extends StatelessWidget {
  const _FeaturedBrandTile({
    required this.brand,
    required this.onTap,
  });

  final HomeFeaturedBrand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(brand.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(brand.cuisine, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(brand.headline, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Text(
                '${brand.etaMinutes} min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.brandPrimaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyBranchTile extends StatelessWidget {
  const _NearbyBranchTile({required this.branch});

  final HomeNearbyBranch branch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(branch.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(branch.tenant.name, style: theme.textTheme.bodySmall),
            if (branch.locationLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(branch.locationLabel, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Text(
              '${branch.distanceKilometers.toStringAsFixed(1)} km · ${branch.etaMinutes} min',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.brandPrimaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({required this.status});

  final LocationAccessStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final message = switch (status) {
      LocationAccessStatus.denied =>
        'El permiso de ubicacion fue denegado. Nearby no debe inventar proximidad, por eso esta seccion puede quedar vacia hasta que el usuario lo permita.',
      LocationAccessStatus.deniedForever =>
        'La ubicacion fue bloqueada permanentemente para la app. Nearby necesita que el usuario la habilite desde ajustes del sistema.',
      LocationAccessStatus.disabled =>
        'Los servicios de ubicacion del dispositivo estan apagados. Nearby requiere GPS real para calcular sucursales cercanas.',
      LocationAccessStatus.unavailable =>
        'No se pudo obtener la ubicacion actual del dispositivo en este intento.',
      LocationAccessStatus.granted => '',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estado de ubicacion', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _EnvironmentCard extends StatelessWidget {
  const _EnvironmentCard({required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configuracion base', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'API_BASE_URL: ${config.apiBaseUrl}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              config.hasSupabaseConfig
                  ? 'Supabase configurado'
                  : 'Falta configurar SUPABASE_URL y SUPABASE_ANON_KEY',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: config.hasSupabaseConfig
                    ? AppColors.brandPrimaryDark
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
