import 'package:flutter/foundation.dart';

class VariantSize {
  String id;
  String size;
  int stock;
  double costPrice;
  double retailPrice;
  String barcode;

  VariantSize({
    required this.id,
    required this.size,
    this.stock = 0,
    this.costPrice = 0.0,
    this.retailPrice = 0.0,
    this.barcode = '',
  });

  factory VariantSize.fromJson(Map<String, dynamic> json) {
    return VariantSize(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      size: json['size']?.toString() ?? '',
      stock: int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      costPrice: double.tryParse(json['cost_price']?.toString() ?? json['costPrice']?.toString() ?? '0') ?? 0.0,
      retailPrice: double.tryParse(json['retail_price']?.toString() ?? json['retailPrice']?.toString() ?? '0') ?? 0.0,
      barcode: json['barcode']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size': size,
      'stock': stock,
      'cost_price': costPrice,
      'retail_price': retailPrice,
      'barcode': barcode,
    };
  }

  VariantSize copyWith({
    String? id,
    String? size,
    int? stock,
    double? costPrice,
    double? retailPrice,
    String? barcode,
  }) {
    return VariantSize(
      id: id ?? this.id,
      size: size ?? this.size,
      stock: stock ?? this.stock,
      costPrice: costPrice ?? this.costPrice,
      retailPrice: retailPrice ?? this.retailPrice,
      barcode: barcode ?? this.barcode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariantSize &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          size == other.size &&
          stock == other.stock &&
          costPrice == other.costPrice &&
          retailPrice == other.retailPrice &&
          barcode == other.barcode;

  @override
  int get hashCode => Object.hash(id, size, stock, costPrice, retailPrice, barcode);
}

class ItemVariant {
  String id;
  String color;
  String imageUrl;
  List<VariantSize> sizes;

  ItemVariant({
    required this.id,
    required this.color,
    this.imageUrl = '',
    List<VariantSize>? sizes,
  }) : sizes = sizes ?? [];

  factory ItemVariant.fromJson(Map<String, dynamic> json) {
    final rawSizes = json['sizes'] as List<dynamic>? ?? [];
    final String rawColor = (json['variant_name'] ?? json['color'] ?? json['name'] ?? '').toString().trim();
    return ItemVariant(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      color: rawColor.isNotEmpty ? rawColor : 'Default',
      imageUrl: json['image_url']?.toString() ?? json['imageUrl']?.toString() ?? '',
      sizes: rawSizes.map((s) => VariantSize.fromJson(Map<String, dynamic>.from(s as Map))).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'color': color,
      'variant_name': color,
      'image_url': imageUrl,
      'sizes': sizes.map((s) => s.toJson()).toList(),
    };
  }

  ItemVariant copyWith({
    String? id,
    String? color,
    String? imageUrl,
    List<VariantSize>? sizes,
  }) {
    return ItemVariant(
      id: id ?? this.id,
      color: color ?? this.color,
      imageUrl: imageUrl ?? this.imageUrl,
      sizes: sizes ?? this.sizes.map((s) => s.copyWith()).toList(),
    );
  }

  int get totalStock => sizes.fold(0, (sum, item) => sum + item.stock);
  
  double get minRetailPrice {
    if (sizes.isEmpty) return 0.0;
    return sizes.map((s) => s.retailPrice).reduce((a, b) => a < b ? a : b);
  }
  
  double get maxRetailPrice {
    if (sizes.isEmpty) return 0.0;
    return sizes.map((s) => s.retailPrice).reduce((a, b) => a > b ? a : b);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemVariant &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          color == other.color &&
          imageUrl == other.imageUrl &&
          listEquals(sizes, other.sizes);

  @override
  int get hashCode => Object.hash(id, color, imageUrl, Object.hashAll(sizes));

  // ─── HELPERS & AUTO GENERATORS ───────────────────────────────────

  static List<String> generateNumericSizes({required int start, required int end, int step = 2}) {
    if (start > end || step <= 0) return [];
    final List<String> result = [];
    for (int i = start; i <= end; i += step) {
      result.add(i.toString());
    }
    return result;
  }

  static List<String> standardPresets() {
    return ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL'];
  }

  void applyRateRule({
    required double baseCost,
    required double costStep,
    required double baseRetail,
    required double retailStep,
    String? startSize,
    String? endSize,
  }) {
    if (sizes.isEmpty) return;

    int startIndex = 0;
    int endIndex = sizes.length - 1;

    if (startSize != null) {
      final sIdx = sizes.indexWhere((s) => s.size == startSize);
      if (sIdx != -1) startIndex = sIdx;
    }
    if (endSize != null) {
      final eIdx = sizes.indexWhere((s) => s.size == endSize);
      if (eIdx != -1) endIndex = eIdx;
    }

    if (startIndex > endIndex) {
      final tmp = startIndex;
      startIndex = endIndex;
      endIndex = tmp;
    }

    int stepIdx = 0;
    for (int i = startIndex; i <= endIndex && i < sizes.length; i++) {
      sizes[i].costPrice = baseCost + (costStep * stepIdx);
      sizes[i].retailPrice = baseRetail + (retailStep * stepIdx);
      stepIdx++;
    }
  }

  void generateBarcodes(String productPrefix) {
    final sanitizePrefix = productPrefix.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final sanitizeColor = color.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    for (var s in sizes) {
      if (s.barcode.isEmpty) {
        s.barcode = '${sanitizePrefix.isNotEmpty ? sanitizePrefix : 'PRD'}-${sanitizeColor.isNotEmpty ? sanitizeColor : 'VAR'}-${s.size}';
      }
    }
  }
}
