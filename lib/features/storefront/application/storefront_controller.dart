import '../domain/storefront_payload.dart';
import '../infrastructure/storefront_api.dart';

class StorefrontController {
  StorefrontController(this._api);

  final StorefrontApi _api;

  Future<StorefrontPayload> load({
    required String tenantSlug,
    String? branchId,
  }) {
    return _api.fetchStorefront(
      tenantSlug: tenantSlug,
      branchId: branchId,
    );
  }

  Future<List<StorefrontProduct>> searchProducts({
    required String tenantSlug,
    required String query,
    String? branchId,
  }) {
    return _api.searchProducts(
      tenantSlug: tenantSlug,
      query: query,
      branchId: branchId,
    );
  }
}
