class AddPlotSize {
  final int id;
  final String size;

  AddPlotSize({
    required this.id,
    required this.size,
  });

  factory AddPlotSize.fromJson(Map<String, dynamic> json) {
    return AddPlotSize(
      id: json['id'],
      size: json['size'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'size': size,
    };
  }
}

//! ADD PLOT NUMBER

class AddPlotNumber {
  final int id;
  String number;
  final DateTime? createdAt;

  AddPlotNumber({
    required this.id,
    required this.number,
    this.createdAt,
  });

  factory AddPlotNumber.fromJson(Map<String, dynamic> json) {
    return AddPlotNumber(
      id: json['id'],
      number: json['number'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}