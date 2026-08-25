class BagPayload {
  const BagPayload({required this.items});

  final List<BagItem> items;

  BagPayload copyWith({List<BagItem>? items}) {
    return BagPayload(items: items ?? this.items);
  }

  factory BagPayload.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      return const BagPayload(items: []);
    }

    return BagPayload(
      items: rawItems
          .whereType<Map>()
          .map((item) => BagItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false),
    );
  }

  bool get isEmpty => items.isEmpty;
}

class BagItem {
  const BagItem({
    required this.id,
    required this.productId,
    required this.productVariantId,
    required this.variantName,
    required this.tenantSlug,
    required this.branchId,
    required this.name,
    required this.description,
    required this.category,
    required this.unitPrice,
    required this.unitPriceLabel,
    required this.quantity,
    required this.modifierSelections,
  });

  final String id;
  final String productId;
  final String? productVariantId;
  final String? variantName;
  final String tenantSlug;
  final String branchId;
  final String name;
  final String description;
  final String category;
  final double unitPrice;
  final String unitPriceLabel;
  final int quantity;
  final List<BagModifierSelection> modifierSelections;

  BagItem copyWith({int? quantity}) {
    return BagItem(
      id: id,
      productId: productId,
      productVariantId: productVariantId,
      variantName: variantName,
      tenantSlug: tenantSlug,
      branchId: branchId,
      name: name,
      description: description,
      category: category,
      unitPrice: unitPrice,
      unitPriceLabel: unitPriceLabel,
      quantity: quantity ?? this.quantity,
      modifierSelections: modifierSelections,
    );
  }

  factory BagItem.fromJson(Map<String, dynamic> json) {
    return BagItem(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      productVariantId: json['productVariantId'] as String?,
      variantName: json['variantName'] as String?,
      tenantSlug: json['tenantSlug'] as String? ?? '',
      branchId: json['branchId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      unitPriceLabel: json['unitPriceLabel'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      modifierSelections:
          (json['modifierSelections'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => BagModifierSelection.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false) ??
          const [],
    );
  }
}

class BagModifierSelection {
  const BagModifierSelection({
    required this.modifierGroupId,
    required this.modifierGroupName,
    required this.modifierOptionId,
    required this.modifierOptionName,
    required this.priceDelta,
  });

  final String modifierGroupId;
  final String modifierGroupName;
  final String modifierOptionId;
  final String modifierOptionName;
  final double priceDelta;

  factory BagModifierSelection.fromJson(Map<String, dynamic> json) {
    return BagModifierSelection(
      modifierGroupId: json['modifierGroupId'] as String? ?? '',
      modifierGroupName: json['modifierGroupName'] as String? ?? '',
      modifierOptionId: json['modifierOptionId'] as String? ?? '',
      modifierOptionName: json['modifierOptionName'] as String? ?? '',
      priceDelta: (json['priceDelta'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'modifierGroupId': modifierGroupId,
      'modifierGroupName': modifierGroupName,
      'modifierOptionId': modifierOptionId,
      'modifierOptionName': modifierOptionName,
      'priceDelta': priceDelta,
    };
  }
}
