class HomePayload {
  const HomePayload({
    required this.heroBanners,
    required this.nearbyBranches,
    required this.featuredBrands,
  });

  final List<HomeHeroBanner> heroBanners;
  final List<HomeNearbyBranch> nearbyBranches;
  final List<HomeFeaturedBrand> featuredBrands;

  factory HomePayload.fromJson(Map<String, dynamic> json) {
    return HomePayload(
      heroBanners: _readList(
        json['heroBanners'],
        (item) => HomeHeroBanner.fromJson(item),
      ),
      nearbyBranches: _readList(
        json['nearbyBranches'],
        (item) => HomeNearbyBranch.fromJson(item),
      ),
      featuredBrands: _readList(
        json['featuredBrands'],
        (item) => HomeFeaturedBrand.fromJson(item),
      ),
    );
  }

  bool get isCompletelyEmpty =>
      heroBanners.isEmpty && nearbyBranches.isEmpty && featuredBrands.isEmpty;

  static List<T> _readList<T>(
    Object? value,
    T Function(Map<String, dynamic> item) fromJson,
  ) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
}

class HomeHeroBanner {
  const HomeHeroBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.tenantSlug,
    required this.branchId,
    required this.ctaLabel,
    required this.ctaHref,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String tenantSlug;
  final String? branchId;
  final String ctaLabel;
  final String ctaHref;

  factory HomeHeroBanner.fromJson(Map<String, dynamic> json) {
    return HomeHeroBanner(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      tenantSlug: json['tenantSlug'] as String? ?? '',
      branchId: json['branchId'] as String?,
      ctaLabel: json['ctaLabel'] as String? ?? '',
      ctaHref: json['ctaHref'] as String? ?? '',
    );
  }
}

class HomeFeaturedBrand {
  const HomeFeaturedBrand({
    required this.id,
    required this.name,
    required this.slug,
    required this.cuisine,
    required this.headline,
    required this.etaMinutes,
    required this.heroImageUrl,
    required this.logoImageUrl,
    required this.storefrontHref,
  });

  final String id;
  final String name;
  final String slug;
  final String cuisine;
  final String headline;
  final int etaMinutes;
  final String? heroImageUrl;
  final String? logoImageUrl;
  final String storefrontHref;

  factory HomeFeaturedBrand.fromJson(Map<String, dynamic> json) {
    return HomeFeaturedBrand(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      cuisine: json['cuisine'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      heroImageUrl: json['heroImageUrl'] as String?,
      logoImageUrl: json['logoImageUrl'] as String?,
      storefrontHref: json['storefrontHref'] as String? ?? '',
    );
  }
}

class HomeNearbyBranch {
  const HomeNearbyBranch({
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
    required this.distanceMeters,
    required this.distanceKilometers,
    required this.etaMinutes,
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
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final double distanceKilometers;
  final int etaMinutes;
  final String storefrontHref;
  final HomeNearbyBranchTenant tenant;

  factory HomeNearbyBranch.fromJson(Map<String, dynamic> json) {
    return HomeNearbyBranch(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      heroImageUrl: json['heroImageUrl'] as String?,
      addressLine1: json['addressLine1'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postalCode'] as String?,
      countryCode: json['countryCode'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      distanceKilometers: (json['distanceKilometers'] as num?)?.toDouble() ?? 0,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      storefrontHref: json['storefrontHref'] as String? ?? '',
      tenant: HomeNearbyBranchTenant.fromJson(
        Map<String, dynamic>.from(
          json['tenant'] as Map? ?? const <String, dynamic>{},
        ),
      ),
    );
  }

  String get locationLabel {
    final parts = [addressLine1, city, state]
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);

    return parts.join(', ');
  }
}

class HomeNearbyBranchTenant {
  const HomeNearbyBranchTenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.logoImageUrl,
    required this.heroImageUrl,
    required this.cuisine,
  });

  final String id;
  final String name;
  final String slug;
  final String? logoImageUrl;
  final String? heroImageUrl;
  final String? cuisine;

  factory HomeNearbyBranchTenant.fromJson(Map<String, dynamic> json) {
    return HomeNearbyBranchTenant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      logoImageUrl: json['logoImageUrl'] as String?,
      heroImageUrl: json['heroImageUrl'] as String?,
      cuisine: json['cuisine'] as String?,
    );
  }
}
