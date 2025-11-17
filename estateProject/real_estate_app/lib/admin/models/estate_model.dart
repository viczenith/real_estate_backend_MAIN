class Estate {
  final int id;
  final String name;
  final String location;
  final String estateSize;
  final String titleDeed;
  final DateTime dateAdded;

  Estate({
    required this.id,
    required this.name,
    required this.location,
    required this.estateSize,
    required this.titleDeed,
    required this.dateAdded,
  });

  factory Estate.fromJson(Map<String, dynamic> json) {
    return Estate(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      estateSize: json['estate_size'],
      titleDeed: json['title_deed'],
      dateAdded: DateTime.parse(json['date_added']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'estate_size': estateSize,
        'title_deed': titleDeed,
        'date_added': dateAdded.toIso8601String(),
      };
}
