class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String category;
  final String? imageUrl;
  final String? sellerName;
  final String? sellerId;
  final int stock;
  final bool hasDiscount;
  final double discountPercentage;
  final List<ProductVariant> variants;
  final List<String> images;
  final String status;
  final DateTime? createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.category,
    this.imageUrl,
    this.sellerName,
    this.sellerId,
    required this.stock,
    this.hasDiscount = false,
    this.discountPercentage = 0.0,
    this.variants = const [],
    this.images = const [],
    this.status = 'active',
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Extract primary image
    String? primaryImageUrl;
    List<String> allImages = [];
    
    if (json['product_images'] != null) {
      List<dynamic> images = json['product_images'];
      for (var img in images) {
        if (img['image_url'] != null) {
          allImages.add(img['image_url'] as String);
          if (img['is_primary'] == true && primaryImageUrl == null) {
            primaryImageUrl = img['image_url'] as String;
          }
        }
      }
    }

    // If no primary image found, use first image or top-level 'image' field
    if (primaryImageUrl == null && allImages.isNotEmpty) {
      primaryImageUrl = allImages.first;
    }
    // Flask API returns a top-level 'image' field as the primary image URL
    if (primaryImageUrl == null && json['image'] != null) {
      primaryImageUrl = json['image'] as String;
    }
    
    // Extract seller info
    String? sellerName;
    String? sellerId;
    if (json['seller'] != null) {
      sellerName = '${json['seller']['first_name'] ?? ''} ${json['seller']['last_name'] ?? ''}'.trim();
      sellerId = json['seller']['id'];
    } else if (json['seller_name'] != null) {
      sellerName = json['seller_name'];
    }
    
    // Calculate discount
    double price = double.tryParse(json['price']?.toString() ?? '0') ?? 0.0;
    double? originalPrice;
    bool hasDiscount = false;
    double discountPercentage = 0.0;
    
    if (json['has_discount'] == true && json['discount_value'] != null) {
      hasDiscount = true;
      if (json['discount_type'] == 'percentage') {
        discountPercentage = double.tryParse(json['discount_value'].toString()) ?? 0.0;
        originalPrice = price / (1 - discountPercentage / 100);
      } else if (json['discount_type'] == 'fixed_amount') {
        double discountAmount = double.tryParse(json['discount_value'].toString()) ?? 0.0;
        originalPrice = price + discountAmount;
        discountPercentage = (discountAmount / originalPrice) * 100;
      }
    }
    
    // Extract variants
    List<ProductVariant> variants = [];
    if (json['variants'] != null) {
      for (var variant in json['variants']) {
        variants.add(ProductVariant.fromJson(variant));
      }
    }
    
    return Product(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: price,
      originalPrice: originalPrice,
      category: json['category'] ?? '',
      imageUrl: primaryImageUrl,
      sellerName: sellerName,
      sellerId: sellerId,
      stock: json['stock'] ?? json['total_stock'] ?? 0,
      hasDiscount: hasDiscount,
      discountPercentage: discountPercentage,
      variants: variants,
      images: allImages,
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'original_price': originalPrice,
      'category': category,
      'image_url': imageUrl,
      'seller_name': sellerName,
      'seller_id': sellerId,
      'stock': stock,
      'has_discount': hasDiscount,
      'discount_percentage': discountPercentage,
      'variants': variants.map((v) => v.toJson()).toList(),
      'images': images,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? category,
    String? imageUrl,
    String? sellerName,
    String? sellerId,
    int? stock,
    bool? hasDiscount,
    double? discountPercentage,
    List<ProductVariant>? variants,
    List<String>? images,
    String? status,
    DateTime? createdAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerName: sellerName ?? this.sellerName,
      sellerId: sellerId ?? this.sellerId,
      stock: stock ?? this.stock,
      hasDiscount: hasDiscount ?? this.hasDiscount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      variants: variants ?? this.variants,
      images: images ?? this.images,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Product{id: $id, name: $name, price: $price, category: $category}';
  }
}

class ProductVariant {
  final String id;
  final String? variantType;
  final String? value;
  final String? size;
  final String? color;
  final String? colorHex;
  final int stock;
  final double price;
  final double finalPrice;
  final String? discountType;
  final double discountValue;
  final String? sku;

  ProductVariant({
    required this.id,
    this.variantType,
    this.value,
    this.size,
    this.color,
    this.colorHex,
    required this.stock,
    required this.price,
    required this.finalPrice,
    this.discountType,
    this.discountValue = 0.0,
    this.sku,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] ?? '',
      variantType: json['variant_type'] as String?,
      value: json['value'] as String?,
      size: json['size'] as String?,
      color: json['color'] as String?,
      colorHex: json['color_hex'] as String?,
      stock: json['stock'] ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      finalPrice: double.tryParse(json['final_price']?.toString() ?? '0') ?? 0.0,
      discountType: json['discount_type'] as String?,
      discountValue: double.tryParse(json['discount_value']?.toString() ?? '0') ?? 0.0,
      sku: json['sku'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'variant_type': variantType,
      'value': value,
      'size': size,
      'color': color,
      'color_hex': colorHex,
      'stock': stock,
      'price': price,
      'final_price': finalPrice,
      'discount_type': discountType,
      'discount_value': discountValue,
      'sku': sku,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductVariant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ProductVariant{id: $id, size: $size, color: $color, price: $finalPrice}';
  }
}
