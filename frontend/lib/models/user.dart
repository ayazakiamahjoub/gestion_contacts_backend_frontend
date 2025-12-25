class User {
  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final DateTime createdAt;

  User({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      firstName: json['first_name'] ?? json['firstName'],
      lastName: json['last_name'] ?? json['lastName'],
      email: json['email'],
      password: json['password'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'password': password,
      'created_at': createdAt.toIso8601String(),
    };
  }
}