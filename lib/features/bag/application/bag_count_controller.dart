import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../infrastructure/bag_api.dart';

class BagCountController extends ChangeNotifier {
  String? _tenantSlug;
  String? _branchId;
  int? _count;
  bool _loading = false;

  int? get count => _count;

  bool _matchesContext(String tenantSlug, String branchId) {
    return _tenantSlug == tenantSlug && _branchId == branchId;
  }

  void setCountForContext({
    required String tenantSlug,
    required String branchId,
    required int count,
  }) {
    if (_matchesContext(tenantSlug, branchId) && _count == count) {
      return;
    }

    _tenantSlug = tenantSlug;
    _branchId = branchId;
    _count = count;
    notifyListeners();
  }

  Future<void> ensureLoaded({
    required String? tenantSlug,
    required String? branchId,
    required AuthSession? authSession,
    required BagApi? bagApi,
  }) async {
    if (tenantSlug == null ||
        tenantSlug.isEmpty ||
        branchId == null ||
        branchId.isEmpty ||
        authSession == null ||
        bagApi == null) {
      if (_tenantSlug != null || _branchId != null || _count != null) {
        _tenantSlug = tenantSlug;
        _branchId = branchId;
        _count = null;
        notifyListeners();
      }
      return;
    }

    final contextChanged = !_matchesContext(tenantSlug, branchId);
    if (contextChanged) {
      _tenantSlug = tenantSlug;
      _branchId = branchId;
      _count = null;
      notifyListeners();
    }

    if (_loading || (!contextChanged && _count != null)) {
      return;
    }

    _loading = true;
    try {
      final accessToken = await authSession.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        if (_matchesContext(tenantSlug, branchId) && _count != null) {
          _count = null;
          notifyListeners();
        }
        return;
      }

      final bag = await bagApi.fetchBag(
        tenantSlug: tenantSlug,
        branchId: branchId,
        accessToken: accessToken,
      );
      if (_matchesContext(tenantSlug, branchId)) {
        _count = bag.items.fold<int>(0, (sum, item) => sum + item.quantity);
        notifyListeners();
      }
    } catch (_) {
      if (_matchesContext(tenantSlug, branchId) && _count != null) {
        _count = null;
        notifyListeners();
      }
    } finally {
      _loading = false;
    }
  }
}
