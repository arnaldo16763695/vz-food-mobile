import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/config/app_config.dart';
import '../core/location/location_service.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/bag/infrastructure/bag_api.dart';
import '../features/branches/infrastructure/branches_api.dart';
import '../features/branches/presentation/branch_detail_screen.dart';
import '../features/bag/application/bag_count_controller.dart';
import '../features/bag/presentation/bag_screen.dart';
import '../features/checkout/infrastructure/checkout_api.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/customer/infrastructure/customer_api.dart';
import '../features/home/infrastructure/home_api.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/marketplace/infrastructure/brands_api.dart';
import '../features/marketplace/presentation/marketplace_screen.dart';
import '../features/orders/infrastructure/orders_api.dart';
import '../features/orders/presentation/order_detail_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/storefront/infrastructure/storefront_api.dart';
import '../features/storefront/presentation/storefront_screen.dart';
import 'auth_redirect.dart';

class AppRouter {
  AppRouter({
    required AppConfig config,
    required AuthSession authSession,
    required AuthAccountService authAccountService,
    required LocationService locationService,
    required BagApi bagApi,
    required BagCountController bagCountController,
    required CheckoutApi checkoutApi,
    required CustomerApi customerApi,
    required OrdersApi ordersApi,
    required HomeApi homeApi,
    required BrandsApi brandsApi,
    required BranchesApi branchesApi,
    required StorefrontApi storefrontApi,
  }) : router = GoRouter(
         refreshListenable: _AuthRefreshListenable(authAccountService),
         redirect: (context, state) => resolveAuthRedirect(
           routePattern: state.fullPath,
           location: state.uri,
           isAuthenticated: authAccountService.currentState().isAuthenticated,
           hasSupabaseConfig: config.hasSupabaseConfig,
         ),
         routes: [
           GoRoute(
             path: '/',
             builder: (context, state) => HomeScreen(
               config: config,
               locationService: locationService,
               homeApi: homeApi,
             ),
           ),
           GoRoute(
             path: '/login',
             builder: (context, state) => LoginScreen(
               authAccountService: authAccountService,
               hasSupabaseConfig: config.hasSupabaseConfig,
               redirectLocation: state.uri.queryParameters['redirect'],
             ),
           ),
           GoRoute(
             path: '/reset-password',
             builder: (context, state) =>
                 ResetPasswordScreen(authAccountService: authAccountService),
           ),
           GoRoute(
             path: '/marketplace',
             builder: (context, state) =>
                 MarketplaceScreen(brandsApi: brandsApi),
           ),
           GoRoute(
             path: '/branches/:branchId',
             builder: (context, state) => BranchDetailScreen(
               branchesApi: branchesApi,
               branchId: state.pathParameters['branchId'] ?? '',
             ),
           ),
           GoRoute(
             path: '/account',
             builder: (context, state) => AccountScreen(
               authAccountService: authAccountService,
               authSession: authSession,
               bagApi: bagApi,
               bagCountController: bagCountController,
               customerApi: customerApi,
               hasSupabaseConfig: config.hasSupabaseConfig,
               tenantSlug: state.uri.queryParameters['tenantSlug'],
               branchId: state.uri.queryParameters['branchId'],
             ),
           ),
           GoRoute(
             path: '/storefront/:tenantSlug',
             builder: (context, state) => StorefrontScreen(
               authSession: authSession,
               bagApi: bagApi,
               bagCountController: bagCountController,
               storefrontApi: storefrontApi,
               tenantSlug: state.pathParameters['tenantSlug'] ?? '',
               branchId: state.uri.queryParameters['branchId'],
             ),
           ),
           GoRoute(
             path: '/storefront/:tenantSlug/bag',
             builder: (context, state) => BagScreen(
               bagApi: bagApi,
               bagCountController: bagCountController,
               authSession: authSession,
               storefrontApi: storefrontApi,
               tenantSlug: state.pathParameters['tenantSlug'] ?? '',
               branchId: state.uri.queryParameters['branchId'] ?? '',
             ),
           ),
           GoRoute(
             path: '/storefront/:tenantSlug/checkout',
             builder: (context, state) => CheckoutScreen(
               authSession: authSession,
               bagApi: bagApi,
               bagCountController: bagCountController,
               customerApi: customerApi,
               checkoutApi: checkoutApi,
               storefrontApi: storefrontApi,
               tenantSlug: state.pathParameters['tenantSlug'] ?? '',
               branchId: state.uri.queryParameters['branchId'] ?? '',
             ),
           ),
           GoRoute(
             path: '/storefront/:tenantSlug/orders',
             builder: (context, state) => OrdersScreen(
               authSession: authSession,
               bagApi: bagApi,
               bagCountController: bagCountController,
               ordersApi: ordersApi,
               tenantSlug: state.pathParameters['tenantSlug'] ?? '',
               branchId: state.uri.queryParameters['branchId'],
             ),
           ),
           GoRoute(
             path: '/storefront/:tenantSlug/orders/:orderId',
             builder: (context, state) => OrderDetailScreen(
               authSession: authSession,
               bagApi: bagApi,
               bagCountController: bagCountController,
               ordersApi: ordersApi,
               tenantSlug: state.pathParameters['tenantSlug'] ?? '',
               orderId: state.pathParameters['orderId'] ?? '',
               branchId: state.uri.queryParameters['branchId'],
             ),
           ),
         ],
       );

  final GoRouter router;
}

/// Bridges the auth stream to GoRouter so the redirect guard re-runs the moment
/// a customer signs in or out.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(AuthAccountService service) {
    _subscription = service.authStateChanges().listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthAccountState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
