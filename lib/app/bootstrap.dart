import 'package:flutter/services.dart';
import '../core/auth/auth_session.dart';
import '../core/auth/supabase_auth_service.dart';
import '../core/config/app_config.dart';
import '../core/location/location_service.dart';
import '../core/network/app_http_client.dart';
import '../features/branches/infrastructure/branches_api.dart';
import '../features/bag/infrastructure/bag_api.dart';
import '../features/bag/application/bag_count_controller.dart';
import '../features/checkout/infrastructure/checkout_api.dart';
import '../features/customer/infrastructure/customer_api.dart';
import '../features/home/infrastructure/home_api.dart';
import '../features/marketplace/infrastructure/brands_api.dart';
import '../features/orders/infrastructure/orders_api.dart';
import '../features/storefront/infrastructure/storefront_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BootstrapData {
  const BootstrapData({
    required this.config,
    required this.httpClient,
    required this.authSession,
    required this.authAccountService,
    required this.locationService,
    required this.homeApi,
    required this.brandsApi,
    required this.branchesApi,
    required this.storefrontApi,
    required this.bagApi,
    required this.bagCountController,
    required this.customerApi,
    required this.checkoutApi,
    required this.ordersApi,
  });

  final AppConfig config;
  final AppHttpClient httpClient;
  final AuthSession authSession;
  final AuthAccountService authAccountService;
  final LocationService locationService;
  final HomeApi homeApi;
  final BrandsApi brandsApi;
  final BranchesApi branchesApi;
  final StorefrontApi storefrontApi;
  final BagApi bagApi;
  final BagCountController bagCountController;
  final CustomerApi customerApi;
  final CheckoutApi checkoutApi;
  final OrdersApi ordersApi;
}

Future<BootstrapData> bootstrapApp() async {
  final config = AppConfig.fromEnvironment();

  final supabaseReady = config.hasSupabaseConfig
      ? await _initializeSupabaseIfNeeded(config)
      : false;

  // Bootstrap is the right place to wire process-wide services before widgets exist.
  // Keeping this out of `main()` makes future additions like Supabase init or crash
  // reporting predictable and easier to maintain.
  final httpClient = AppHttpClient.create(config: config);
  final authSession = supabaseReady
      ? SupabaseAuthSession(Supabase.instance.client)
      : NoopAuthSession();
  final authAccountService = supabaseReady
      ? SupabaseAccountService(
          Supabase.instance.client,
          authRedirectUrl: config.authRedirectUrl,
        )
      : _NoopAuthAccountService();
  final locationService = GeolocatorLocationService();
  final homeApi = HomeApi(httpClient.dio);
  final brandsApi = BrandsApi(httpClient.dio);
  final branchesApi = BranchesApi(httpClient.dio);
  final storefrontApi = StorefrontApi(httpClient.dio);
  final bagApi = BagApi(httpClient.dio);
  final bagCountController = BagCountController();
  final customerApi = CustomerApi(httpClient.dio);
  final checkoutApi = CheckoutApi(httpClient.dio);
  final ordersApi = OrdersApi(httpClient.dio);

  return BootstrapData(
    config: config,
    httpClient: httpClient,
    authSession: authSession,
    authAccountService: authAccountService,
    locationService: locationService,
    homeApi: homeApi,
    brandsApi: brandsApi,
    branchesApi: branchesApi,
    storefrontApi: storefrontApi,
    bagApi: bagApi,
    bagCountController: bagCountController,
    customerApi: customerApi,
    checkoutApi: checkoutApi,
    ordersApi: ordersApi,
  );
}

bool _supabaseInitialized = false;

Future<bool> _initializeSupabaseIfNeeded(AppConfig config) async {
  if (_supabaseInitialized) {
    return true;
  }

  // Bootstrap owns SDK initialization so the rest of the app can depend on a
  // ready auth client instead of scattering setup rules across UI code.
  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
    _supabaseInitialized = true;
    return true;
  } on MissingPluginException {
    // This usually happens right after adding a plugin dependency and only doing
    // hot reload/hot restart. The app should stay usable in a degraded mode until
    // the next full native restart registers shared_preferences and Supabase.
    return false;
  } on PlatformException {
    return false;
  }
}

class _NoopAuthAccountService implements AuthAccountService {
  @override
  Stream<AuthAccountState> authStateChanges() async* {
    yield currentState();
  }

  @override
  Stream<AuthLifecycleEvent> lifecycleEvents() => const Stream.empty();

  @override
  AuthAccountState currentState() {
    return const AuthAccountState(isAuthenticated: false);
  }

  @override
  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    throw StateError('Supabase is not configured.');
  }

  @override
  Future<AuthSignUpResult> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    throw StateError('Supabase is not configured.');
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    throw StateError('Supabase is not configured.');
  }

  @override
  Future<void> updatePassword({required String newPassword}) async {
    throw StateError('Supabase is not configured.');
  }

  @override
  Future<void> signOut() async {}
}
