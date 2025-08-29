class Order {
  final String id;

  // raqamlar
  final String? number; // masalan ORD-2025-08-01-001 yoki backendda number
  final String? dailyNumber; // kunlik raqam (agar alohida maydon bo'lsa)
  final String?
      status; // created | edit_requested | editable | packed | shipped
  final String? note;

  // vaqt tamg'asi (PocketBase record default)
  final String? created;

  // relation ID'lar
  final String? dealerId;
  final String? managerId;
  final String? regionId;
  final String? warehouseId;

  // discount
  final String? discountType; // 'none' | 'percent' | 'amount'
  final double? discountValue;

  // expand (label ko'rsatish uchun)
  final Map<String, dynamic>? expand;

  Order({
    required this.id,
    this.number,
    this.dailyNumber,
    this.status,
    this.note,
    this.created,
    this.dealerId,
    this.managerId,
    this.regionId,
    this.warehouseId,
    this.discountType,
    this.discountValue,
    this.expand,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final exp = (json['expand'] is Map<String, dynamic>)
        ? json['expand'] as Map<String, dynamic>
        : null;

    String? _safeString(dynamic v) => v == null ? null : v.toString();

    double? _safeDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Order(
      id: json['id'] as String,
      number: _safeString(json['number']) ??
          _safeString(json['human_id']) ??
          _safeString(json['ord_number']),
      dailyNumber: _safeString(json['daily_number']) ??
          _safeString(json['human_id_daily']),
      status: _safeString(json['status']),
      note: _safeString(json['note']),
      created: _safeString(json['created']),
      dealerId: _safeString(json['dealer']),
      managerId: _safeString(json['manager']),
      regionId: _safeString(json['region']),
      warehouseId: _safeString(json['warehouse']),
      discountType: _safeString(json['discount_type']) ??
          _safeString(json['discountType']) ??
          'none',
      discountValue:
          _safeDouble(json['discount_value'] ?? json['discountValue']),
      expand: exp,
    );
  }

  String get numberOrId {
    if ((dailyNumber ?? '').isNotEmpty) return dailyNumber!;
    if ((number ?? '').isNotEmpty) return number!;
    return '#$id';
  }

  String? get expandDealerName => expand?['dealer']?['name']?.toString();
  String? get expandManagerName => expand?['manager']?['name']?.toString();
  String? get expandRegionName => expand?['region']?['name']?.toString();
  String? get expandWarehouseName => expand?['warehouse']?['name']?.toString();

  String get dealerLabel => expandDealerName ?? dealerId ?? '-';
  String get managerLabel => expandManagerName ?? managerId ?? '-';
  String get regionLabel => expandRegionName ?? regionId ?? '-';
  String get warehouseLabel => expandWarehouseName ?? warehouseId ?? '-';
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final double? qty;
  final double? unitPriceUsd;
  final Map<String, dynamic>? expand;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    this.qty,
    this.unitPriceUsd,
    this.expand,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    double? _safeDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final exp = (json['expand'] is Map<String, dynamic>)
        ? json['expand'] as Map<String, dynamic>
        : null;

    return OrderItem(
      id: json['id'] as String,
      orderId: json['order']?.toString() ?? '',
      productId: json['product']?.toString() ?? '',
      qty: _safeDouble(json['qty']),
      unitPriceUsd: _safeDouble(
          json['unit_price_usd'] ?? json['unitPriceUsd'] ?? json['price_usd']),
      expand: exp,
    );
  }

  String? get expandProductName => expand?['product']?['name']?.toString();
}
