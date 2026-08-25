class StorefrontLink {
  const StorefrontLink({required this.tenantSlug, required this.branchId});

  final String tenantSlug;
  final String? branchId;

  static StorefrontLink? tryParse(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null) {
      return null;
    }

    final segments = uri.pathSegments;
    if (segments.length < 2) {
      return null;
    }

    final appIndex = segments.indexOf('app');
    if (appIndex == -1 || appIndex + 1 >= segments.length) {
      return null;
    }

    return StorefrontLink(
      tenantSlug: segments[appIndex + 1],
      branchId: uri.queryParameters['branch'],
    );
  }

  String get routeLocation {
    final branchQuery = branchId == null || branchId!.isEmpty
        ? ''
        : '?branchId=$branchId';
    return '/storefront/$tenantSlug$branchQuery';
  }
}
