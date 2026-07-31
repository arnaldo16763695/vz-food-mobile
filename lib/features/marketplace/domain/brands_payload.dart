import 'brand_summary.dart';

class BrandsPayload {
  const BrandsPayload({required this.brands});

  final List<BrandSummary> brands;

  factory BrandsPayload.fromJson(Map<String, dynamic> json) {
    final rawBrands = json['brands'];
    if (rawBrands is! List) {
      return const BrandsPayload(brands: []);
    }

    return BrandsPayload(
      brands: rawBrands
          .whereType<Map>()
          .map((item) => BrandSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }

  bool get isEmpty => brands.isEmpty;
}
