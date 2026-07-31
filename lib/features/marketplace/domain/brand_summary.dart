class BrandSummary {
  const BrandSummary({
    required this.id,
    required this.name,
    required this.slug,
    required this.cuisine,
    required this.headline,
    required this.nearestBranch,
    required this.etaMinutes,
    required this.accent,
    required this.heroImageUrl,
    required this.logoImageUrl,
    required this.storefrontHref,
    required this.activeBranchCount,
  });

  final String id;
  final String name;
  final String slug;
  final String cuisine;
  final String headline;
  final String nearestBranch;
  final int etaMinutes;
  final String accent;
  final String? heroImageUrl;
  final String? logoImageUrl;
  final String storefrontHref;
  final int activeBranchCount;

  factory BrandSummary.fromJson(Map<String, dynamic> json) {
    return BrandSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      cuisine: json['cuisine'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      nearestBranch: json['nearestBranch'] as String? ?? '',
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      accent: json['accent'] as String? ?? '',
      heroImageUrl: json['heroImageUrl'] as String?,
      logoImageUrl: json['logoImageUrl'] as String?,
      storefrontHref: json['storefrontHref'] as String? ?? '',
      activeBranchCount: (json['activeBranchCount'] as num?)?.toInt() ?? 0,
    );
  }
}
