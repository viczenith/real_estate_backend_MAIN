class AppUser {
  final String fullName;
  final String password;
  final String address;
  final String phone;
  final String email;
  final String dateOfBirth;
  final String role;
  final int? marketerId;

  AppUser({
    required this.fullName,
    required this.password,
    required this.address,
    required this.phone,
    required this.email,
    required this.dateOfBirth,
    required this.role,
    this.marketerId,
  });

  Map<String, dynamic> toJson() {
    final data = {
      'full_name': fullName,
      'password': password,
      'address': address,
      'phone': phone,
      'email': email,
      'date_of_birth': dateOfBirth,
      'role': role,
    };

    if (role == 'client' && marketerId != null) {
      data['marketer_id'] = marketerId.toString();
    }

    return data;
  }
}
