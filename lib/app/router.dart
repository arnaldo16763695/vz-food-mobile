import 'package:go_router/go_router.dart';

import '../core/auth/auth_session.dart';
import '../core/config/app_config.dart';
import '../core/location/location_service.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/bag/infrastructure/bag_api.dart';
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
    required StorefrontApi storefrontApi,
  }) : router = GoRouter(
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
             path: '/marketplace',
             builder: (context, state) =>
                 MarketplaceScreen(brandsApi: brandsApi),
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
