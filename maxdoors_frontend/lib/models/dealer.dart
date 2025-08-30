class Dealer {
  final String id;
  final String name;

  Dealer({required this.id, required this.name});

  factory Dealer.fromJson(Map<String, dynamic> json) {
    return Dealer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '(no name)',
    );
  }
}
