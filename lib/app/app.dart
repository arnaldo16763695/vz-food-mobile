import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';
import 'bootstrap.dart';

class VzFoodApp extends StatelessWidget {
  const VzFoodApp({
    super.key,
    required this.bootstrapData,
  });

  final BootstrapData bootstrapData;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VZ Food',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: AppRouter(
        config: bootstrapData.config,
        locationService: bootstrapData.locationService,
        homeApi: bootstrapData.homeApi,
        brandsApi: bootstrapData.brandsApi,
        storefrontApi: bootstrapData.storefrontApi,
        authSession: bootstrapData.authSession,
        authAccountService: bootstrapData.authAccountService,
        bagApi: bootstrapData.bagApi,
        bagCountController: bootstrapData.bagCountController,
        customerApi: bootstrapData.customerApi,
        checkoutApi: bootstrapData.checkoutApi,
        ordersApi: bootstrapData.ordersApi,
      ).router,
    );
  }
}
