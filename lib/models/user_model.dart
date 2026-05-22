class UserModel {
  final int id;
  final String name;
  final String email;
  final List<String> roles;
  final Company? company;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    this.company,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      roles: List<String>.from(json['roles']),
      company: json['company'] != null ? Company.fromJson(json['company']) : null,
    );
  }
}

class Company {
  final int id;
  final String name;

  Company({
    required this.id,
    required this.name,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      name: json['name'],
    );
  }
}
