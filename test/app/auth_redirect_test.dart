import 'package:flutter_test/flutter_test.dart';
import 'package:vz_food/app/auth_redirect.dart';

// Covers the pure GoRouter guard decision: public routes stay open, the four
// authenticated storefront routes bounce to /login with a round-trip target,
// and /login never traps an already-signed-in customer.

void main() {
  group('resolveAuthRedirect', () {
    test('allows public routes when signed out', () {
      expect(
        resolveAuthRedirect(
          routePattern: '/',
          location: Uri.parse('/'),
          isAuthenticated: false,
          hasSupabaseConfig: true,
        ),
        isNull,
      );
      expect(
        resolveAuthRedirect(
          routePattern: '/storefront/:tenantSlug',
          location: Uri.parse('/storefront/acme?branchId=b1'),
          isAuthenticated: false,
          hasSupabaseConfig: true,
        ),
        isNull,
      );
    });

    test('redirects protected routes to /login with the original location', () {
      final result = resolveAuthRedirect(
        routePattern: '/storefront/:tenantSlug/checkout',
        location: Uri.parse('/storefront/acme/checkout?branchId=b1'),
        isAuthenticated: false,
        hasSupabaseConfig: true,
      );

      expect(
        result,
        '/login?redirect=${Uri.encodeComponent('/storefront/acme/checkout?branchId=b1')}',
      );
    });

    test('gates every protected route pattern', () {
      for (final pattern in protectedRoutePatterns) {
        final result = resolveAuthRedirect(
          routePattern: pattern,
          location: Uri.parse('/storefront/acme/bag'),
          isAuthenticated: false,
          hasSupabaseConfig: true,
        );
        expect(result, startsWith('/login?redirect='), reason: pattern);
      }
    });

    test('lets authenticated customers into protected routes', () {
      expect(
        resolveAuthRedirect(
          routePattern: '/storefront/:tenantSlug/bag',
          location: Uri.parse('/storefront/acme/bag?branchId=b1'),
          isAuthenticated: true,
          hasSupabaseConfig: true,
        ),
        isNull,
      );
    });

    test('does not gate protected routes when Supabase is not configured', () {
      expect(
        resolveAuthRedirect(
          routePattern: '/storefront/:tenantSlug/orders',
          location: Uri.parse('/storefront/acme/orders'),
          isAuthenticated: false,
          hasSupabaseConfig: false,
        ),
        isNull,
      );
    });

    test('bounces /login to the pending redirect when already authenticated', () {
      expect(
        resolveAuthRedirect(
          routePattern: '/login',
          location: Uri.parse(
            '/login?redirect=${Uri.encodeComponent('/storefront/acme/bag?branchId=b1')}',
          ),
          isAuthenticated: true,
          hasSupabaseConfig: true,
        ),
        '/storefront/acme/bag?branchId=b1',
      );
    });

    test('bounces /login to home when authenticated with no redirect', () {
      expect(
        resolveAuthRedirect(
          routePattern: '/login',
          location: Uri.parse('/login'),
          isAuthenticated: true,
          hasSupabaseConfig: true,
        ),
        '/',
      );
    });

    test('sends signed-out customers off /reset-password to /login', () {
      expect(
        resolveAuthRedirect(
          routePattern: '/reset-password',
          location: Uri.parse('/reset-password'),
          isAuthenticated: false,
          hasSupabaseConfig: true,
        ),
        '/login',
      );
    });

    test('allows /reset-password with a (recovery) session', () {
      expect(
        resolveAuthRedirect(
          routePattern: '/reset-password',
          location: Uri.parse('/reset-password'),
          isAuthenticated: true,
          hasSupabaseConfig: true,
        ),
        isNull,
      );
    });

    test('keeps signed-out customers on /login', () {
      expect(
        resolveAuthRedirect(
          routePattern: '/login',
          location: Uri.parse('/login?redirect=%2Fstorefront%2Facme%2Fbag'),
          isAuthenticated: false,
          hasSupabaseConfig: true,
        ),
        isNull,
      );
    });
  });
}
