import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/customer_footer_nav.dart';
import '../../bag/application/bag_count_controller.dart';
import '../../bag/infrastructure/bag_api.dart';
import '../../customer/infrastructure/customer_api.dart';
import '../../storefront/domain/storefront_payload.dart';
import '../../storefront/infrastructure/storefront_api.dart';
import '../application/checkout_controller.dart';
import '../domain/checkout_models.dart';
import '../infrastructure/checkout_api.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.authSession,
    required this.bagApi,
    required this.bagCountController,
    required this.customerApi,
    required this.checkoutApi,
    required this.storefrontApi,
    required this.tenantSlug,
    required this.branchId,
  });

  final AuthSession authSession;
  final BagApi bagApi;
  final BagCountController bagCountController;
  final CustomerApi customerApi;
  final CheckoutApi checkoutApi;
  final StorefrontApi storefrontApi;
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
  int _currentStep = 0;
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
      widget.storefrontApi,
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
      _currentStep = 0;
      _submitting = false;
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

  String? _firstPersonalValidationError() {
    if (_fullNameController.text.trim().isEmpty) {
      return 'Ingresa el nombre completo';
    }

    if (_phoneController.text.trim().isEmpty) {
      return 'Ingresa el telefono';
    }

    if (_emailController.text.trim().isEmpty) {
      return 'Ingresa el email';
    }

    return null;
  }

  bool _validatePersonalStep({bool preferFormValidation = true}) {
    final formState = _formKey.currentState;
    if (preferFormValidation && formState != null) {
      return formState.validate();
    }

    return _firstPersonalValidationError() == null;
  }

  void _goToPaymentStep() {
    if (!_validatePersonalStep()) {
      return;
    }

    setState(() {
      _currentStep = 1;
    });
  }

  Future<void> _submit(CheckoutLoadData data) async {
    final branch = data.branch;
    if (branch != null && !branch.acceptingOrders) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            branch.closureLabel?.trim().isNotEmpty == true
                ? branch.closureLabel!
                : 'Esta sucursal no esta aceptando pedidos ahora mismo.',
          ),
        ),
      );
      return;
    }

    if (!_validatePersonalStep(preferFormValidation: false)) {
      setState(() {
        _currentStep = 0;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _formKey.currentState?.validate();
      });

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

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Orden creada'),
            content: Text(
              result.orderNumber != null
                  ? 'Tu orden #${result.orderNumber} fue creada con exito.'
                  : 'Tu orden fue creada con exito.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ver pedidos'),
              ),
            ],
          );
        },
      );
      if (!mounted) {
        return;
      }

      final branchQuery = widget.branchId.isEmpty ? '' : '?branchId=${widget.branchId}';
      context.go('/storefront/${widget.tenantSlug}/orders$branchQuery');
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
      bottomNavigationBar: CustomerFooterNav(
        currentTab: CustomerFooterTab.bag,
        tenantSlug: widget.tenantSlug,
        branchId: widget.branchId,
        authSession: widget.authSession,
        bagApi: widget.bagApi,
        bagCountController: widget.bagCountController,
      ),
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

            final totalItems = data.bag.items.fold<int>(
              0,
              (sum, item) => sum + item.quantity,
            );
            final totalAmount = data.bag.items.fold<double>(
              0,
              (sum, item) => sum + (item.unitPrice * item.quantity),
            );
            final activeBranch = data.branch;

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
                        'Completa tus datos y luego elige el metodo de pago para crear la orden con comprobante obligatorio.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _CheckoutStepHeader(currentStep: _currentStep),
                const SizedBox(height: 16),
                if (activeBranch != null && !activeBranch.acceptingOrders) ...[
                  _BranchOrderingClosedCard(branch: activeBranch),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumen de la bolsa de compra',
                          style: theme.textTheme.titleLarge,
                        ),
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
                                Text(
                                  item.unitPriceLabel.isEmpty
                                      ? AppFormatters.currency(item.unitPrice)
                                      : item.unitPriceLabel,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _currentStep == 0
                      ? _CheckoutPersonalStep(
                          key: const ValueKey('personal-step'),
                          formKey: _formKey,
                          fullNameController: _fullNameController,
                          phoneController: _phoneController,
                          emailController: _emailController,
                          notesController: _notesController,
                          onNext: _goToPaymentStep,
                        )
                      : _CheckoutPaymentStep(
                          key: const ValueKey('payment-step'),
                          paymentMethod: _paymentMethod,
                          paymentSettings: data.paymentSettings,
                          totalItems: totalItems,
                          totalAmount: totalAmount,
                          branch: activeBranch,
                          paymentProofPath: _paymentProofPath,
                          submitting: _submitting,
                          onBack: () {
                            setState(() {
                              _currentStep = 0;
                            });
                          },
                          onPickPaymentProof: _pickPaymentProof,
                          onPaymentMethodChanged: (value) {
                            setState(() {
                              _paymentMethod = value;
                            });
                          },
                          onSubmit: () => _submit(data),
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

class _CheckoutStepHeader extends StatelessWidget {
  const _CheckoutStepHeader({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepBadge(
            stepNumber: 1,
            title: 'Datos personales',
            isActive: currentStep == 0,
            isCompleted: currentStep > 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StepBadge(
            stepNumber: 2,
            title: 'Metodo de pago',
            isActive: currentStep == 1,
            isCompleted: false,
          ),
        ),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.stepNumber,
    required this.title,
    required this.isActive,
    required this.isCompleted,
  });

  final int stepNumber;
  final String title;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = isActive || isCompleted
        ? AppColors.brandPrimary
        : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.brandPrimary.withValues(alpha: 0.10)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? AppColors.brandPrimary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: accentColor,
            child: Text(
              '$stepNumber',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.brandPrimaryDark : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutPersonalStep extends StatelessWidget {
  const _CheckoutPersonalStep({
    super.key,
    required this.formKey,
    required this.fullNameController,
    required this.phoneController,
    required this.emailController,
    required this.notesController,
    required this.onNext,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController notesController;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paso 1: datos personales', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: fullNameController,
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el nombre completo'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Telefono'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el telefono'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa el email'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onNext,
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutPaymentStep extends StatelessWidget {
  const _CheckoutPaymentStep({
    super.key,
    required this.paymentMethod,
    required this.paymentSettings,
    required this.branch,
    required this.totalItems,
    required this.totalAmount,
    required this.paymentProofPath,
    required this.submitting,
    required this.onBack,
    required this.onPickPaymentProof,
    required this.onPaymentMethodChanged,
    required this.onSubmit,
  });

  final CheckoutPaymentMethod paymentMethod;
  final CheckoutPaymentSettings paymentSettings;
  final StorefrontBranch? branch;
  final int totalItems;
  final double totalAmount;
  final String? paymentProofPath;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onPickPaymentProof;
  final ValueChanged<CheckoutPaymentMethod> onPaymentMethodChanged;
  final VoidCallback onSubmit;

  String get _instructions {
    switch (paymentMethod) {
      case CheckoutPaymentMethod.mobilePayment:
        return paymentSettings.mobilePaymentInstructions?.trim().isNotEmpty == true
            ? paymentSettings.mobilePaymentInstructions!.trim()
            : 'Usa los datos de pago movil del comercio y adjunta tu comprobante para continuar.';
      case CheckoutPaymentMethod.bankTransfer:
        return paymentSettings.bankTransferInstructions?.trim().isNotEmpty == true
            ? paymentSettings.bankTransferInstructions!.trim()
            : 'Usa los datos de transferencia del comercio y adjunta tu comprobante para continuar.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canCheckout = branch?.acceptingOrders ?? true;

    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paso 2: metodo de pago', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<CheckoutPaymentMethod>(
              initialValue: paymentMethod,
              items: CheckoutPaymentMethod.values
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(method.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  onPaymentMethodChanged(value);
                }
              },
              decoration: const InputDecoration(labelText: 'Metodo de pago'),
            ),
            const SizedBox(height: 16),
            Container(
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
                  Text(
                    paymentMethod.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_instructions, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen final',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CheckoutSummaryRow(
                    label: 'Metodo seleccionado',
                    value: paymentMethod.label,
                  ),
                  const SizedBox(height: 8),
                  _CheckoutSummaryRow(
                    label: 'Productos',
                    value: '$totalItems',
                  ),
                  const SizedBox(height: 8),
                  _CheckoutSummaryRow(
                    label: 'Total estimado',
                    value: AppFormatters.currency(totalAmount),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onPickPaymentProof,
              child: Text(
                paymentProofPath == null
                    ? 'Adjuntar comprobante obligatorio'
                    : 'Cambiar comprobante',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              paymentProofPath == null
                  ? 'Debes adjuntar un comprobante para crear la orden.'
                  : File(paymentProofPath!).uri.pathSegments.last,
              style: theme.textTheme.bodySmall?.copyWith(
                color: paymentProofPath == null ? Colors.red.shade700 : null,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: submitting ? null : onBack,
                    child: const Text('Anterior'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: !canCheckout || submitting ? null : onSubmit,
                    child: Text(submitting ? 'Enviando...' : 'Crear orden'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchOrderingClosedCard extends StatelessWidget {
  const _BranchOrderingClosedCard({required this.branch});

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
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A5300),
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

class _CheckoutSummaryRow extends StatelessWidget {
  const _CheckoutSummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: (emphasize
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium)
              ?.copyWith(
                fontWeight: FontWeight.w700,
                color: emphasize ? AppColors.brandPrimaryDark : null,
              ),
        ),
      ],
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
            'La bolsa de compra esta vacia o no hay datos suficientes para iniciar checkout.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
