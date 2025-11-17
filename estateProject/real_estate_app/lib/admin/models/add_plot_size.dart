class PlotSize {
  final String id;
  final String size;

  PlotSize({required this.id, required this.size});

  factory PlotSize.fromJson(Map<String, dynamic> json) {
    return PlotSize(id: json['id'].toString(), size: json['size']);
  }
}