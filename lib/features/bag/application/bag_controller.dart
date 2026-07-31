import '../../../core/auth/auth_session.dart';
import 'bag_load_result.dart';
import '../infrastructure/bag_api.dart';

class BagController {
  BagController(this._bagApi, this._authSession);

  final BagApi _bagApi;
  final AuthSession _authSession;

  Future<BagLoadResult> load({
    required String tenantSlug,
    required String branchId,
  }) async {
    // Bag is an authenticated surface. We keep the auth dependency explicit here
    // so the future Supabase integration can plug in once and all bag flows will
    // benefit without pushing token logic down into widgets.
    final accessToken = await _authSession.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      return const BagLoadResult(status: BagAccessStatus.unauthenticated);
    }

    final payload = await _bagApi.fetchBag(
      tenantSlug: tenantSlug,
      branchId: branchId,
      accessToken: accessToken,
    );

    return BagLoadResult(
      status: BagAccessStatus.authenticated,
      payload: payload,
    );
  }
}
