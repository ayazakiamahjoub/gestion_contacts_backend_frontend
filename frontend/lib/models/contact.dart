class Contact {
  final int? id;
  final int userId;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final DateTime createdAt;

  Contact({
    this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      userId: json['user_id'] ?? json['userId'],
      firstName: json['first_name'] ?? json['firstName'],
      lastName: json['last_name'] ?? json['lastName'],
      phone: json['phone'],
      email: json['email'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'email': email,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Contact copyWith({
    int? id,
    int? userId,
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    DateTime? createdAt,
  }) {
    return Contact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}