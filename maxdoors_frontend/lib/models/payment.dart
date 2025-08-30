class Payment {
  final String id;

  // relations
  final String? dealerId;
  final String? orderId; // agar sizda bog‘liq bo‘lsa
  final String? managerId; // agar sizda bo‘lsa

  // fields
  final DateTime? date;
  final double? amount;
  final String? currency; // 'USD' | 'UZS'
  final String? method; // 'cash' | 'card' | 'bank'
  final String? note;

  // rates
  final double? rate; // USD→UZS
  final double? amountUsd; // USD hisobidagi ekvivalent

  // expand (label uchun)
  final Map<String, dynamic>? expand;

  Payment({
    required this.id,
    this.dealerId,
    this.orderId,
    this.managerId,
    this.date,
    this.amount,
    this.currency,
    this.method,
    this.note,
    this.rate,
    this.amountUsd,
    this.expand,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    double? _d(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final exp = (json['expand'] is Map<String, dynamic>)
        ? json['expand'] as Map<String, dynamic>
        : null;

    return Payment(
      id: (json['id'] ?? '').toString(),
      dealerId: json['dealer']?.toString(),
      orderId: json['order']?.toString(),
      managerId: json['manager']?.toString(),
      date: _parseDate(json['date'] ?? json['created']),
      amount: _d(json['amount']),
      currency: json['currency']?.toString(),
      method: json['method']?.toString(),
      note: json['note']?.toString(),
      rate: _d(json['rate']),
      amountUsd: _d(json['amount_usd'] ?? json['amountUsd']),
      expand: exp,
    );
  }

  String get dealerLabel =>
      expand?['dealer']?['name']?.toString() ?? dealerId ?? '-';

  String get amountLabel {
    final a = amount ?? 0;
    final cur = currency ?? '';
    return '${a.toStringAsFixed(2)} $cur';
  }

  String get dateLabel {
    final dt = date;
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}
