import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../application/branch_detail_controller.dart';
import '../domain/branch_detail.dart';
import '../infrastructure/branches_api.dart';

/// Public branch detail reached by tapping a "Sucursales cercanas" card on the
/// home screen. Ends with a CTA into the tenant storefront for that branch.
class BranchDetailScreen extends StatefulWidget {
  const BranchDetailScreen({
    super.key,
    required this.branchesApi,
    required this.branchId,
  });

  final BranchesApi branchesApi;
  final String branchId;

  @override
  State<BranchDetailScreen> createState() => _BranchDetailScreenState();
}

class _BranchDetailScreenState extends State<BranchDetailScreen> {
  late final BranchDetailController _controller;
  late Future<BranchDetailPayload> _future;

  @override
  void initState() {
    super.initState();
    _controller = BranchDetailController(widget.branchesApi);
    _future = _load();
  }

  Future<BranchDetailPayload> _load() {
    return _controller.load(branchId: widget.branchId);
  }

  void _retry() {
    setState(() {
      _future = _load();
    });
  }

  void _openStorefront(BranchDetail branch) {
    context.push('/storefront/${branch.tenant.slug}?branchId=${branch.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sucursal')),
      body: SafeArea(
        child: FutureBuilder<BranchDetailPayload>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _BranchDetailError(error: snapshot.error, onRetry: _retry);
            }

            final branch = snapshot.data?.branch;
            if (branch == null || branch.id.isEmpty) {
              return const _BranchDetailEmpty();
            }

            return _BranchDetailBody(
              branch: branch,
              onOpenStorefront: () => _openStorefront(branch),
            );
          },
        ),
      ),
    );
  }
}

class _BranchDetailBody extends StatelessWidget {
  const _BranchDetailBody({
    required this.branch,
    required this.onOpenStorefront,
  });

  final BranchDetail branch;
  final VoidCallback onOpenStorefront;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = branch.locationLabel;
    final cityLine = [branch.postalCode, branch.countryCode]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' · ');

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
                branch.name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                branch.tenant.name,
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              _StatePill(isActive: branch.isActive),
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
                Text('Ubicacion', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                  address.isEmpty ? 'Sin direccion registrada' : address,
                  style: theme.textTheme.bodyMedium,
                ),
                if (cityLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(cityLine, style: theme.textTheme.bodySmall),
                ],
                if (branch.latitude != null && branch.longitude != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${branch.latitude!.toStringAsFixed(5)}, ${branch.longitude!.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
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
                Text('Local', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(branch.tenant.name, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  branch.tenant.storefrontEnabled
                      ? 'Storefront habilitado'
                      : 'Storefront no disponible',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (!branch.canOpenStorefront)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              branch.isActive
                  ? 'Este local aun no tiene storefront disponible.'
                  : 'Esta sucursal esta inactiva por ahora.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: branch.canOpenStorefront ? onOpenStorefront : null,
            child: const Text('Ver menu'),
          ),
        ),
      ],
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Activa' : 'Inactiva',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BranchDetailError extends StatelessWidget {
  const _BranchDetailError({required this.error, required this.onRetry});

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
                'No se pudo cargar la sucursal',
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

class _BranchDetailEmpty extends StatelessWidget {
  const _BranchDetailEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No hay informacion disponible para esta sucursal.'),
    );
  }
}
