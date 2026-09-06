class BranchDetailPayload {
  const BranchDetailPayload({required this.branch});

  final BranchDetail branch;

  factory BranchDetailPayload.fromJson(Map<String, dynamic> json) {
    return BranchDetailPayload(
      branch: BranchDetail.fromJson(
        Map<String, dynamic>.from(
          json['branch'] as Map? ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}

class BranchDetail {
  const BranchDetail({
    required this.id,
    required this.name,
    required this.heroImageUrl,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.storefrontHref,
    required this.tenant,
  });

  final String id;
  final String name;
  final String? heroImageUrl;
  final String? addressLine1;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? countryCode;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final String? storefrontHref;
  final BranchDetailTenant tenant;

  /// True only when the branch is active *and* its tenant has the storefront
  /// enabled — the two conditions the menu route needs.
  bool get canOpenStorefront => isActive && tenant.storefrontEnabled;

  /// "Calle 1, Ciudad, Estado" from whatever address parts are present.
  String get locationLabel {
    return [addressLine1, city, state]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  factory BranchDetail.fromJson(Map<String, dynamic> json) {
    return BranchDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      heroImageUrl: json['heroImageUrl'] as String?,
      addressLine1: json['addressLine1'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String?,
      countryCode: json['countryCode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isActive: json['isActive'] as bool? ?? false,
      storefrontHref: json['storefrontHref'] as String?,
      tenant: BranchDetailTenant.fromJson(
        Map<String, dynamic>.from(
          json['tenant'] as Map? ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}

class BranchDetailTenant {
  const BranchDetailTenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.logoImageUrl,
    required this.heroImageUrl,
    required this.storefrontEnabled,
  });

  final String id;
  final String name;
  final String slug;
  final String? logoImageUrl;
  final String? heroImageUrl;
  final bool storefrontEnabled;

  factory BranchDetailTenant.fromJson(Map<String, dynamic> json) {
    return BranchDetailTenant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      logoImageUrl: json['logoImageUrl'] as String?,
      heroImageUrl: json['heroImageUrl'] as String?,
      storefrontEnabled: json['storefrontEnabled'] as bool? ?? false,
    );
  }
}
