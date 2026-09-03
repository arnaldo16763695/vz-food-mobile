import 'dart:async';

import 'package:flutter/material.dart';

import '../core/auth/auth_session.dart';
import '../core/theme/app_theme.dart';
import 'bootstrap.dart';
import 'router.dart';

class VzFoodApp extends StatefulWidget {
  const VzFoodApp({super.key, required this.bootstrapData});

  final BootstrapData bootstrapData;

  @override
  State<VzFoodApp> createState() => _VzFoodAppState();
}

class _VzFoodAppState extends State<VzFoodApp> {
  late final AppRouter _appRouter;
  StreamSubscription<AuthLifecycleEvent>? _lifecycleSubscription;

  @override
  void initState() {
    super.initState();
    final data = widget.bootstrapData;
    _appRouter = AppRouter(
      config: data.config,
      locationService: data.locationService,
      homeApi: data.homeApi,
      brandsApi: data.brandsApi,
      storefrontApi: data.storefrontApi,
      authSession: data.authSession,
      authAccountService: data.authAccountService,
      bagApi: data.bagApi,
      bagCountController: data.bagCountController,
      customerApi: data.customerApi,
      checkoutApi: data.checkoutApi,
      ordersApi: data.ordersApi,
    );

    // A password-recovery deep link signs the customer into a short-lived
    // session; route them straight to the "set new password" screen.
    _lifecycleSubscription = data.authAccountService.lifecycleEvents().listen((
      event,
    ) {
      if (event == AuthLifecycleEvent.passwordRecovery) {
        _appRouter.router.go('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    _lifecycleSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VZ Food',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _appRouter.router,
    );
  }
}
