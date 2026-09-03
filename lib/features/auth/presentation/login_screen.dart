import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_error.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/theme/app_colors.dart';

enum _AuthMode { signIn, signUp, reset }

/// Dedicated authentication surface. The route guard sends unauthenticated
/// customers here with a `redirect` target; on success we return them to it.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authAccountService,
    required this.hasSupabaseConfig,
    this.redirectLocation,
  });

  final AuthAccountService authAccountService;
  final bool hasSupabaseConfig;
  final String? redirectLocation;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _AuthMode _mode = _AuthMode.signIn;
  bool _submitting = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _needsPassword => _mode != _AuthMode.reset;

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _errorMessage = null;
      _infoMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      switch (_mode) {
        case _AuthMode.signIn:
          await widget.authAccountService.signInWithEmailPassword(
            email: email,
            password: password,
          );
          _goAfterAuth();
        case _AuthMode.signUp:
          final result = await widget.authAccountService
              .signUpWithEmailPassword(email: email, password: password);
          if (!mounted) {
            return;
          }
          if (result.needsEmailConfirmation) {
            setState(() {
              _mode = _AuthMode.signIn;
              _infoMessage =
                  'Te enviamos un correo para confirmar tu cuenta. Confirmala y '
                  'luego inicia sesion.';
            });
          } else {
            _goAfterAuth();
          }
        case _AuthMode.reset:
          await widget.authAccountService.sendPasswordReset(email: email);
          if (!mounted) {
            return;
          }
          setState(() {
            _mode = _AuthMode.signIn;
            _infoMessage =
                'Si el correo existe, te enviamos un enlace para restablecer tu '
                'contrasena.';
          });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = describeAuthError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _goAfterAuth() {
    if (!mounted) {
      return;
    }
    final target = widget.redirectLocation;
    context.go(target != null && target.isNotEmpty ? target : '/');
  }

  String get _primaryLabel {
    switch (_mode) {
      case _AuthMode.signIn:
        return _submitting ? 'Ingresando...' : 'Entrar';
      case _AuthMode.signUp:
        return _submitting ? 'Creando cuenta...' : 'Crear cuenta';
      case _AuthMode.reset:
        return _submitting ? 'Enviando...' : 'Enviar enlace';
    }
  }

  String get _headline {
    switch (_mode) {
      case _AuthMode.signIn:
        return 'Iniciar sesion';
      case _AuthMode.signUp:
        return 'Crear cuenta';
      case _AuthMode.reset:
        return 'Recuperar contrasena';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: SafeArea(
        child: ListView(
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
                    _headline,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Inicia sesion para continuar con tu bolsa, checkout y '
                    'pedidos.',
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
            else
              _buildForm(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_headline, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return 'Ingresa tu email';
                  }
                  if (!text.contains('@') || !text.contains('.')) {
                    return 'Ingresa un email valido';
                  }
                  return null;
                },
              ),
              if (_needsPassword) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Password'),
                  validator: (value) {
                    if (!_needsPassword) {
                      return null;
                    }
                    final text = value ?? '';
                    if (text.isEmpty) {
                      return 'Ingresa tu password';
                    }
                    if (_mode == _AuthMode.signUp && text.length < 6) {
                      return 'Minimo 6 caracteres';
                    }
                    return null;
                  },
                ),
              ],
              if (_infoMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _infoMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.brandPrimaryDark,
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_primaryLabel),
                ),
              ),
              const SizedBox(height: 8),
              ..._buildModeLinks(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildModeLinks() {
    switch (_mode) {
      case _AuthMode.signIn:
        return [
          TextButton(
            onPressed: _submitting ? null : () => _switchMode(_AuthMode.reset),
            child: const Text('Olvide mi contrasena'),
          ),
          Row(
            children: [
              Text(
                'No tienes cuenta?',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => _switchMode(_AuthMode.signUp),
                child: const Text('Crear cuenta'),
              ),
            ],
          ),
        ];
      case _AuthMode.signUp:
        return [
          TextButton(
            onPressed: _submitting ? null : () => _switchMode(_AuthMode.signIn),
            child: const Text('Ya tengo cuenta, iniciar sesion'),
          ),
        ];
      case _AuthMode.reset:
        return [
          TextButton(
            onPressed: _submitting ? null : () => _switchMode(_AuthMode.signIn),
            child: const Text('Volver a iniciar sesion'),
          ),
        ];
    }
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
          'Falta configurar SUPABASE_URL y SUPABASE_ANON_KEY en .env para '
          'habilitar autenticacion real.',
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
