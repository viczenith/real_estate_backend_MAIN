class Client {
  final int id;
  final String name;
  final String email;
  final String phone;

  Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  // Factory constructor to create a Client from JSON
  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
    );
  }
}