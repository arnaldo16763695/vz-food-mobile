/// Route patterns (GoRouter `fullPath` form) that require an authenticated
/// customer. Public discovery — home, marketplace, storefront and menu — stays
/// open; only bag mutation, checkout and orders are gated, matching the
/// backend's authenticated endpoint surface.
const protectedRoutePatterns = <String>{
  '/storefront/:tenantSlug/bag',
  '/storefront/:tenantSlug/checkout',
  '/storefront/:tenantSlug/orders',
  '/storefront/:tenantSlug/orders/:orderId',
};

const loginRoutePath = '/login';
const resetPasswordRoutePath = '/reset-password';

/// Pure decision for the GoRouter redirect guard. Returns the location to
/// redirect to, or `null` to allow the navigation as-is.
///
/// - An unauthenticated hit on a protected route is sent to
///   `/login?redirect=<original location>` so the customer lands back where
///   they intended after signing in.
/// - `/reset-password` only makes sense with a (recovery) session; without one
///   it falls back to plain `/login`.
/// - An authenticated hit on `/login` bounces to the pending `redirect` target
///   (or home) so the login screen is never a dead end.
/// - When Supabase is not configured there is no real session to gate on, so
///   protected routes are left alone and the screens themselves surface the
///   "auth not configured" state.
String? resolveAuthRedirect({
  required String? routePattern,
  required Uri location,
  required bool isAuthenticated,
  required bool hasSupabaseConfig,
}) {
  if (location.path == loginRoutePath) {
    if (isAuthenticated) {
      final target = location.queryParameters['redirect'];
      return (target != null && target.isNotEmpty) ? target : '/';
    }
    return null;
  }

  if (location.path == resetPasswordRoutePath) {
    return isAuthenticated ? null : loginRoutePath;
  }

  if (!hasSupabaseConfig || isAuthenticated) {
    return null;
  }

  if (routePattern != null && protectedRoutePatterns.contains(routePattern)) {
    return '$loginRoutePath?redirect=${Uri.encodeComponent(location.toString())}';
  }

  return null;
}
