import '../../../core/location/location_service.dart';
import '../domain/home_payload.dart';

class HomeLoadResult {
  const HomeLoadResult({required this.payload, required this.locationStatus});

  final HomePayload payload;
  final LocationAccessStatus locationStatus;

  bool get hasLocation => locationStatus == LocationAccessStatus.granted;
}
