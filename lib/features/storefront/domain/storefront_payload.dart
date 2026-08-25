class StorefrontPayload {
  const StorefrontPayload({required this.storefront});

  final Storefront storefront;

  factory StorefrontPayload.fromJson(Map<String, dynamic> json) {
    return StorefrontPayload(
      storefront: Storefront.fromJson(
        Map<String, dynamic>.from(
          json['storefront'] as Map? ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}

class Storefront {
  const Storefront({
    required this.tenant,
    required this.branches,
    required this.activeBranch,
    required this.etaMinutes,
    required this.menu,
    required this.shareUrl,
  });

  final StorefrontTenant tenant;
  final List<StorefrontBranch> branches;
  final StorefrontBranch? activeBranch;
  final int etaMinutes;
  final List<StorefrontProduct> menu;
  final String shareUrl;

  factory Storefront.fromJson(Map<String, dynamic> json) {
    return Storefront(
      tenant: StorefrontTenant.fromJson(
        Map<String, dynamic>.from(
          json['tenant'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      branches: _readList(
        json['branches'],
        (item) => StorefrontBranch.fromJson(item),
      ),
      activeBranch: json['activeBranch'] is Map
          ? StorefrontBranch.fromJson(
              Map<String, dynamic>.from(json['activeBranch'] as Map),
            )
          : null,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      menu: _readList(json['menu'], (item) => StorefrontProduct.fromJson(item)),
      shareUrl: json['shareUrl'] as String? ?? '',
    );
  }

  bool get hasMenu => menu.isNotEmpty;

  Map<String, List<StorefrontProduct>> get menuByCategory {
    final grouped = <String, List<StorefrontProduct>>{};

    for (final product in menu) {
      final category = product.category.trim().isEmpty
          ? 'Sin categoria'
          : product.category.trim();
      grouped.putIfAbsent(category, () => <StorefrontProduct>[]).add(product);
    }

    return grouped;
  }

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

class StorefrontTenant {
  const StorefrontTenant({
    required this.id,
    required this.name,
    required this.slug,
    required this.customDomain,
    required this.storefrontEnabled,
    required this.heroImageUrl,
    required this.logoImageUrl,
  });

  final String id;
  final String name;
  final String slug;
  final String? customDomain;
  final bool storefrontEnabled;
  final String? heroImageUrl;
  final String? logoImageUrl;

  factory StorefrontTenant.fromJson(Map<String, dynamic> json) {
    return StorefrontTenant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      customDomain: json['customDomain'] as String?,
      storefrontEnabled: json['storefrontEnabled'] as bool? ?? false,
      heroImageUrl: json['heroImageUrl'] as String?,
      logoImageUrl: json['logoImageUrl'] as String?,
    );
  }
}

class StorefrontBranch {
  const StorefrontBranch({
    required this.id,
    required this.name,
    required this.heroImageUrl,
    required this.isOpenNow,
    required this.acceptingOrders,
    required this.orderingMode,
    required this.closureLabel,
    required this.nextTransitionAt,
    required this.nextTransitionLabel,
  });

  final String id;
  final String name;
  final String? heroImageUrl;
  final bool isOpenNow;
  final bool acceptingOrders;
  final String orderingMode;
  final String? closureLabel;
  final DateTime? nextTransitionAt;
  final String? nextTransitionLabel;

  bool get isClosedForOrdering => !acceptingOrders;

  factory StorefrontBranch.fromJson(Map<String, dynamic> json) {
    return StorefrontBranch(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      heroImageUrl: json['heroImageUrl'] as String?,
      isOpenNow: json['isOpenNow'] as bool? ?? false,
      acceptingOrders: json['acceptingOrders'] as bool? ?? false,
      orderingMode: json['orderingMode'] as String? ?? 'auto',
      closureLabel: json['closureLabel'] as String?,
      nextTransitionAt: json['nextTransitionAt'] is String
          ? DateTime.tryParse(json['nextTransitionAt'] as String)
          : null,
      nextTransitionLabel: json['nextTransitionLabel'] as String?,
    );
  }
}

class StorefrontProduct {
  const StorefrontProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.hasVariants,
    required this.variants,
    required this.modifierGroups,
    required this.category,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final String basePrice;
  final bool hasVariants;
  final List<StorefrontProductVariant> variants;
  final List<StorefrontModifierGroup> modifierGroups;
  final String category;
  final String? imageUrl;

  bool get hasRequiredModifiers =>
      modifierGroups.any((group) => group.minSelect > 0);

  bool get requiresCustomization => hasVariants || hasRequiredModifiers;

  String? get defaultVariantId {
    for (final variant in variants) {
      if (variant.isDefault) {
        return variant.id;
      }
    }

    return variants.isNotEmpty ? variants.first.id : null;
  }

  factory StorefrontProduct.fromJson(Map<String, dynamic> json) {
    return StorefrontProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      basePrice: json['basePrice'] as String? ?? '',
      hasVariants: json['hasVariants'] as bool? ?? false,
      variants: Storefront._readList(
        json['variants'],
        (item) => StorefrontProductVariant.fromJson(item),
      ),
      modifierGroups: Storefront._readList(
        json['modifierGroups'],
        (item) => StorefrontModifierGroup.fromJson(item),
      ),
      category: json['category'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class StorefrontProductVariant {
  const StorefrontProductVariant({
    required this.id,
    required this.name,
    required this.basePrice,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String basePrice;
  final bool isDefault;

  factory StorefrontProductVariant.fromJson(Map<String, dynamic> json) {
    return StorefrontProductVariant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      basePrice: json['basePrice'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

class StorefrontModifierGroup {
  const StorefrontModifierGroup({
    required this.id,
    required this.name,
    required this.selectionType,
    required this.modifierKind,
    required this.minSelect,
    required this.maxSelect,
    required this.options,
  });

  final String id;
  final String name;
  final String selectionType;
  final String modifierKind;
  final int minSelect;
  final int maxSelect;
  final List<StorefrontModifierOption> options;

  bool get isSingleSelection => selectionType == 'single';

  factory StorefrontModifierGroup.fromJson(Map<String, dynamic> json) {
    return StorefrontModifierGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      selectionType: json['selectionType'] as String? ?? 'single',
      modifierKind: json['modifierKind'] as String? ?? 'choice',
      minSelect: (json['minSelect'] as num?)?.toInt() ?? 0,
      maxSelect: (json['maxSelect'] as num?)?.toInt() ?? 0,
      options: Storefront._readList(
        json['options'],
        (item) => StorefrontModifierOption.fromJson(item),
      ),
    );
  }
}

class StorefrontModifierOption {
  const StorefrontModifierOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.priceDeltaLabel,
    required this.defaultSelected,
  });

  final String id;
  final String name;
  final double priceDelta;
  final String priceDeltaLabel;
  final bool defaultSelected;

  factory StorefrontModifierOption.fromJson(Map<String, dynamic> json) {
    return StorefrontModifierOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceDelta: (json['priceDelta'] as num?)?.toDouble() ?? 0,
      priceDeltaLabel: json['priceDeltaLabel'] as String? ?? '',
      defaultSelected: json['defaultSelected'] as bool? ?? false,
    );
  }
}
