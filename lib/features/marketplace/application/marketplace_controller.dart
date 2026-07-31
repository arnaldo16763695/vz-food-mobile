import '../domain/brands_payload.dart';
import '../infrastructure/brands_api.dart';

class MarketplaceController {
  MarketplaceController(this._brandsApi);

  final BrandsApi _brandsApi;

  Future<BrandsPayload> load() {
    return _brandsApi.fetchBrands();
  }
}
