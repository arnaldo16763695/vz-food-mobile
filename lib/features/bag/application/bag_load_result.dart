import '../domain/bag_payload.dart';

enum BagAccessStatus { authenticated, unauthenticated }

class BagLoadResult {
  const BagLoadResult({required this.status, this.payload});

  final BagAccessStatus status;
  final BagPayload? payload;

  bool get requiresLogin => status == BagAccessStatus.unauthenticated;
}
