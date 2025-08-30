class Order {
  final String id;

  // raqamlar
  final String? number; // masalan ORD-2025-08-01-001
  final String?
      dailyNumber; // kunlik tartib raqami (ORD-YYYY-MM-DD-001 kabi bo‘lishi mumkin)
  final String?
      status; // created | edit_requested | editable | packed | shipped
  final String? note;

  // vaqt
  final String? created;

  // relation ID’lar
  final String? dealerId;
  final String? managerId; // ← yaratuvchi user shu yerda
  final String? regionId;
  final String? warehouseId;

  // chegirma
  final String? discountType; // none | percent | amount
  final double? discountValue; // USD

  // expand
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
    String? _s(dynamic v) => v == null ? null : v.toString();
    double? _d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final exp = (json['expand'] is Map<String, dynamic>)
        ? json['expand'] as Map<String, dynamic>
        : null;

    return Order(
      id: json['id'] as String,
      number:
          _s(json['number']) ?? _s(json['human_id']) ?? _s(json['ord_number']),
      dailyNumber: _s(json['daily_number']) ?? _s(json['human_id_daily']),
      status: _s(json['status']),
      note: _s(json['note']),
      created: _s(json['created']),
      dealerId: _s(json['dealer']),
      managerId: _s(json['manager']), // yaratuvchi shu
      regionId: _s(json['region']),
      warehouseId: _s(json['warehouse']),
      discountType:
          _s(json['discount_type']) ?? _s(json['discountType']) ?? 'none',
      discountValue: _d(json['discount_value'] ?? json['discountValue']),
      expand: exp,
    );
  }

  /// Ro‘yxatda ko‘rinadigan raqam
  String get numberOrId {
    if ((dailyNumber ?? '').isNotEmpty) return dailyNumber!;
    if ((number ?? '').isNotEmpty) return number!;
    return '#$id';
  }

  // expand label helpers
  String? get expandDealerName => expand?['dealer']?['name']?.toString();
  String? get expandManagerName => expand?['manager']?['name']?.toString();
  String? get expandRegionName => expand?['region']?['name']?.toString();
  String? get expandWarehouseName => expand?['warehouse']?['name']?.toString();

  String get dealerLabel => expandDealerName ?? dealerId ?? '-';
  String get managerLabel => expandManagerName ?? managerId ?? '-';
  String get regionLabel => expandRegionName ?? regionId ?? '-';
  String get warehouseLabel => expandWarehouseName ?? warehouseId ?? '-';

  /// Statusni o‘zbekcha ko‘rinishi
  String get statusUz {
    switch ((status ?? '').toLowerCase()) {
      case 'created':
        return 'Yaratildi';
      case 'edit_requested':
        return 'Tahrir so‘rovi';
      case 'editable':
        return 'Tahrirlash mumkin';
      case 'packed':
        return 'Yig‘ildi';
      case 'shipped':
        return 'Jo‘natildi';
      default:
        return status ?? '-';
    }
  }
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
    double? _d(dynamic v) {
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
      qty: _d(json['qty']),
      unitPriceUsd: _d(
          json['unit_price_usd'] ?? json['unitPriceUsd'] ?? json['price_usd']),
      expand: exp,
    );
  }

  String? get expandProductName => expand?['product']?['name']?.toString();
}
