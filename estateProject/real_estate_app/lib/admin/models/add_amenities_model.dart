class Amenity {
  final String code;
  final String name;
  final String icon;

  Amenity({
    required this.code,
    required this.name,
    required this.icon,
  });
  

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      
    );
  }
}