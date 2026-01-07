enum TransactionType { income, expense }

class TransactionModel {
  final int? id;
  final DateTime date;
  final double amount;
  final String category;
  final TransactionType type;
  final String? description;

  TransactionModel({
    this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.type,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'category': category,
      'type': type.index,
      'description': description,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      date: DateTime.parse(map['date']),
      amount: map['amount'],
      category: map['category'],
      type: TransactionType.values[map['type']],
      description: map['description'],
    );
  }
}
