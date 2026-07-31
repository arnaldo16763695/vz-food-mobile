import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../bag/infrastructure/bag_api.dart';
import '../../customer/infrastructure/customer_api.dart';
import '../application/checkout_controller.dart';
import '../domain/checkout_models.dart';
import '../infrastructure/checkout_api.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.authSession,
    required this.bagApi,
    required this.customerApi,
    required this.checkoutApi,
    required this.tenantSlug,
    required this.branchId,
  });

  final AuthSession authSession;
  final BagApi bagApi;
  final CustomerApi customerApi;
  final CheckoutApi checkoutApi;
  final String tenantSlug;
  final String branchId;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  late final CheckoutController _controller;
  late Future<CheckoutLoadData> _future;

  CheckoutPaymentMethod _paymentMethod = CheckoutPaymentMethod.mobilePayment;
  String? _paymentProofPath;
  bool _submitting = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _controller = CheckoutController(
      widget.authSession,
      widget.bagApi,
      widget.customerApi,
      widget.checkoutApi,
    );
    _future = _load();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<CheckoutLoadData> _load() {
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

  void _prefillIfNeeded(CheckoutLoadData data) {
    if (_prefilled) {
      return;
    }

    final customer = data.customer.customer.customer;
    _fullNameController.text = customer.fullName ?? '';
    _phoneController.text = customer.phone ?? '';
    _emailController.text = customer.email ?? data.customer.customer.user.email;
    _prefilled = true;
  }

  Future<void> _pickPaymentProof() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) {
      return;
    }

    setState(() {
      _paymentProofPath = file.path;
    });
  }

  Future<void> _submit(CheckoutLoadData data) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_paymentProofPath == null || _paymentProofPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjunta un comprobante de pago.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final result = await _controller.submit(
        CheckoutSubmission(
          tenantSlug: widget.tenantSlug,
          branchId: widget.branchId,
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          notes: _notesController.text.trim(),
          paymentMethod: _paymentMethod,
          paymentProofPath: _paymentProofPath!,
          items: data.bag.items,
        ),
      );

      if (!mounted) {
        return;
      }

      if (!result.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'No se pudo crear la orden.'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Orden creada${result.orderNumber != null ? ' #${result.orderNumber}' : ''}.',
          ),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar checkout: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: FutureBuilder<CheckoutLoadData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _CheckoutError(
                error: snapshot.error,
                onRetry: _retry,
              );
            }

            final data = snapshot.data;
            if (data == null || data.bag.isEmpty) {
              return const _CheckoutEmpty();
            }

            _prefillIfNeeded(data);

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
                        'Checkout pickup',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Usamos bag + customer/me para reducir errores de captura antes de crear la orden.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
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
                        Text('Resumen del bag', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        ...data.bag.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x ${item.name}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Text(item.unitPriceLabel, style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Datos del cliente', style: theme.textTheme.titleLarge),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _fullNameController,
                            decoration: const InputDecoration(labelText: 'Nombre completo'),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Ingresa el nombre completo'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(labelText: 'Telefono'),
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Ingresa el telefono'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(labelText: 'Email'),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) => value == null || value.trim().isEmpty
                                ? 'Ingresa el email'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                          ),
                        ],
                      ),
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
                        Text('Pago manual', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<CheckoutPaymentMethod>(
                          initialValue: _paymentMethod,
                          items: CheckoutPaymentMethod.values
                              .map(
                                (method) => DropdownMenuItem(
                                  value: method,
                                  child: Text(method.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _paymentMethod = value;
                            });
                          },
                          decoration: const InputDecoration(labelText: 'Metodo de pago'),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _pickPaymentProof,
                          child: Text(
                            _paymentProofPath == null
                                ? 'Adjuntar comprobante'
                                : 'Cambiar comprobante',
                          ),
                        ),
                        if (_paymentProofPath != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            File(_paymentProofPath!).uri.pathSegments.last,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitting ? null : () => _submit(data),
                  child: Text(_submitting ? 'Enviando...' : 'Crear orden'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CheckoutError extends StatelessWidget {
  const _CheckoutError({required this.error, required this.onRetry});

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
              Text('No se pudo preparar checkout', style: theme.textTheme.titleLarge),
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

class _CheckoutEmpty extends StatelessWidget {
  const _CheckoutEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'El bag esta vacio o no hay datos suficientes para iniciar checkout.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
