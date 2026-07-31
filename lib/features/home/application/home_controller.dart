import '../../../core/location/location_service.dart';
import 'home_load_result.dart';
import '../infrastructure/home_api.dart';

class HomeController {
  HomeController(this._homeApi, this._locationService);

  final HomeApi _homeApi;
  final LocationService _locationService;

  Future<HomeLoadResult> load() async {
    // Nearby discovery is GPS-first in this product. We attempt location before
    // calling home so the backend can return branch-aware data when permission exists.
    final locationResult = await _locationService.getCurrentCoordinates();

    final payload = await _homeApi.fetchHome(
      latitude: locationResult.coordinates?.latitude,
      longitude: locationResult.coordinates?.longitude,
    );

    return HomeLoadResult(
      payload: payload,
      locationStatus: locationResult.status,
    );
  }
}
