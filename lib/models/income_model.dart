class IncomeModel {
  final int? id;
  final DateTime date;
  final double amount;
  final String category;
  final int profileId; // Linked Profile
  final String? description;

  IncomeModel({
    this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.profileId,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'category': category,
      'profileId': profileId,
      'description': description,
    };
  }

  factory IncomeModel.fromMap(Map<String, dynamic> map) {
    return IncomeModel(
      id: map['id'],
      date: DateTime.parse(map['date']),
      amount: map['amount'],
      category: map['category'],
      profileId: map['profileId'],
      description: map['description'],
    );
  }
}
