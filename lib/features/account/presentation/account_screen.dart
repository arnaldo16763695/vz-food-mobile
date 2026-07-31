import 'package:flutter/material.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../customer/application/customer_controller.dart';
import '../../customer/domain/customer_context.dart';
import '../../customer/infrastructure/customer_api.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.authAccountService,
    required this.authSession,
    required this.customerApi,
    required this.hasSupabaseConfig,
  });

  final AuthAccountService authAccountService;
  final AuthSession authSession;
  final CustomerApi customerApi;
  final bool hasSupabaseConfig;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final CustomerController _customerController;

  bool _submitting = false;
  String? _errorMessage;
  Future<CustomerContextPayload?>? _customerFuture;

  @override
  void initState() {
    super.initState();
    _customerController = CustomerController(
      widget.customerApi,
      widget.authSession,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authAccountService.signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) {
        setState(() {
          _customerFuture = _customerController.load();
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await widget.authAccountService.signOut();
    if (mounted) {
      setState(() {
        _customerFuture = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: SafeArea(
        child: StreamBuilder<AuthAccountState>(
          stream: widget.authAccountService.authStateChanges(),
          initialData: widget.authAccountService.currentState(),
          builder: (context, snapshot) {
            final state = snapshot.data ??
                const AuthAccountState(isAuthenticated: false);

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
                    customerFuture: _customerFuture ?? _customerController.load(),
                    state: state,
                    onSignOut: _signOut,
                  )
                else
                  _SignInCard(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    submitting: _submitting,
                    errorMessage: _errorMessage,
                    onSubmit: _signIn,
                  ),
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

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({
    required this.state,
    required this.onSignOut,
  });

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
            Text(state.userId ?? 'Sin user id', style: theme.textTheme.bodySmall),
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
            _ProfileRow(label: 'Nombre', value: customer.customer.fullName ?? 'Sin nombre'),
            _ProfileRow(label: 'Email', value: customer.customer.email ?? customer.user.email),
            _ProfileRow(label: 'Telefono', value: customer.customer.phone ?? 'Sin telefono'),
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
            Text('No se pudo cargar customer/me', style: theme.textTheme.titleLarge),
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
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.submitting,
    required this.errorMessage,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool submitting;
  final String? errorMessage;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Iniciar sesion', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa tu email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa tu password';
                  }
                  return null;
                },
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: submitting ? null : onSubmit,
                child: Text(submitting ? 'Ingresando...' : 'Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
