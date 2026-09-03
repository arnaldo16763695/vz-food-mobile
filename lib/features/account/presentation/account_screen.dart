import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/customer_footer_nav.dart';
import '../../bag/application/bag_count_controller.dart';
import '../../bag/infrastructure/bag_api.dart';
import '../../customer/application/customer_controller.dart';
import '../../customer/domain/customer_context.dart';
import '../../customer/infrastructure/customer_api.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.authAccountService,
    required this.authSession,
    required this.bagApi,
    required this.bagCountController,
    required this.customerApi,
    required this.hasSupabaseConfig,
    required this.tenantSlug,
    required this.branchId,
  });

  final AuthAccountService authAccountService;
  final AuthSession authSession;
  final BagApi bagApi;
  final BagCountController bagCountController;
  final CustomerApi customerApi;
  final bool hasSupabaseConfig;
  final String? tenantSlug;
  final String? branchId;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final CustomerController _customerController;
  StreamSubscription<AuthAccountState>? _authSubscription;

  Future<CustomerContextPayload?>? _customerFuture;

  @override
  void initState() {
    super.initState();
    _customerController = CustomerController(
      widget.customerApi,
      widget.authSession,
    );

    if (widget.authAccountService.currentState().isAuthenticated) {
      _customerFuture = _customerController.load();
    }

    // The backend profile is only meaningful while a session exists. Refresh it
    // when the customer signs in from `/login`; drop it on sign-out.
    _authSubscription = widget.authAccountService.authStateChanges().listen((
      state,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _customerFuture = state.isAuthenticated
            ? _customerController.load()
            : null;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    await widget.authAccountService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      bottomNavigationBar: CustomerFooterNav(
        currentTab: CustomerFooterTab.profile,
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        authSession: widget.authSession,
        bagApi: widget.bagApi,
        bagCountController: widget.bagCountController,
      ),
      body: SafeArea(
        child: StreamBuilder<AuthAccountState>(
          stream: widget.authAccountService.authStateChanges(),
          initialData: widget.authAccountService.currentState(),
          builder: (context, snapshot) {
            final state =
                snapshot.data ?? const AuthAccountState(isAuthenticated: false);

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
                        'Cuenta del cliente',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        state.isAuthenticated
                            ? 'Sesion activa como ${state.email ?? 'cliente'}.'
                            : 'Inicia sesion para usar bag, checkout y pedidos autenticados.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!widget.hasSupabaseConfig)
                  const _ConfigWarningCard()
                else if (state.isAuthenticated)
                  _AuthenticatedAccountSection(
                    customerFuture:
                        _customerFuture ?? _customerController.load(),
                    state: state,
                    onSignOut: _signOut,
                  )
                else
                  const _SignInPromptCard(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConfigWarningCard extends StatelessWidget {
  const _ConfigWarningCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Falta configurar SUPABASE_URL y SUPABASE_ANON_KEY en .env para habilitar autenticacion real.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _SignInPromptCard extends StatelessWidget {
  const _SignInPromptCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No has iniciado sesion', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Inicia sesion o crea una cuenta para gestionar tu bolsa, pagar y '
              'seguir tus pedidos.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/login'),
              child: const Text('Iniciar sesion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({required this.state, required this.onSignOut});

  final AuthAccountState state;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sesion activa', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(state.email ?? 'Sin email', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              state.userId ?? 'Sin user id',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onSignOut,
              child: const Text('Cerrar sesion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthenticatedAccountSection extends StatelessWidget {
  const _AuthenticatedAccountSection({
    required this.customerFuture,
    required this.state,
    required this.onSignOut,
  });

  final Future<CustomerContextPayload?> customerFuture;
  final AuthAccountState state;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SignedInCard(state: state, onSignOut: onSignOut),
        const SizedBox(height: 16),
        FutureBuilder<CustomerContextPayload?>(
          future: customerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return _CustomerProfileError(error: snapshot.error);
            }

            final payload = snapshot.data;
            if (payload == null) {
              return const _CustomerProfileEmpty();
            }

            return _CustomerProfileCard(payload: payload);
          },
        ),
      ],
    );
  }
}

class _CustomerProfileCard extends StatelessWidget {
  const _CustomerProfileCard({required this.payload});

  final CustomerContextPayload payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = payload.customer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Perfil del backend', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _ProfileRow(
              label: 'Nombre',
              value: customer.customer.fullName ?? 'Sin nombre',
            ),
            _ProfileRow(
              label: 'Email',
              value: customer.customer.email ?? customer.user.email,
            ),
            _ProfileRow(
              label: 'Telefono',
              value: customer.customer.phone ?? 'Sin telefono',
            ),
            _ProfileRow(
              label: 'Marketing',
              value: customer.customer.marketingOptIn ? 'Activo' : 'Inactivo',
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerProfileError extends StatelessWidget {
  const _CustomerProfileError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No se pudo cargar customer/me',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text('$error', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CustomerProfileEmpty extends StatelessWidget {
  const _CustomerProfileEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No hay contexto de customer disponible.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
