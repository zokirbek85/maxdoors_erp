class Product {
  final String id;
  final String name;
  final String? category; // id
  final String unit;
  final double priceUsd;
  final String? barcode;
  final double stockOk;
  final double stockDefect;
  final double avgCostUsd;

  Product({
    required this.id,
    required this.name,
    this.category,
    required this.unit,
    required this.priceUsd,
    this.barcode,
    required this.stockOk,
    required this.stockDefect,
    required this.avgCostUsd,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    double _d(v) => v is num ? v.toDouble() : 0.0;
    return Product(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      category: j['category'],
      unit: j['unit'] ?? '',
      priceUsd: _d(j['price_usd']),
      barcode: j['barcode'],
      stockOk: _d(j['stock_ok']),
      stockDefect: _d(j['stock_defect']),
      avgCostUsd: _d(j['avg_cost_usd']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'unit': unit,
    'price_usd': priceUsd,
    'barcode': barcode,
    'stock_ok': stockOk,
    'stock_defect': stockDefect,
    'avg_cost_usd': avgCostUsd,
  };
}
