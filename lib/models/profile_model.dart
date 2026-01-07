class ProfileModel {
  final int? id;
  final String name;
  final int colorValue; // ARGB int

  ProfileModel({this.id, required this.name, required this.colorValue});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'colorValue': colorValue};
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'],
      name: map['name'],
      colorValue: map['colorValue'],
    );
  }

  ProfileModel copyWith({int? id, String? name, int? colorValue}) {
    return ProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }
}
