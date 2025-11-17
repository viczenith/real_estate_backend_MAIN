class PlotNumber {
  final int id;
  final String number;

  PlotNumber({
    required this.id,
    required this.number,
  });

  factory PlotNumber.fromJson(Map<String, dynamic> json) {
    return PlotNumber(
      id: json['id'],
      number: json['number'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
      };
}
