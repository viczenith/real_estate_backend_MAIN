import 'dart:convert';
import 'package:real_estate_app/admin/others/edit_estate_plot_modal.dart';

EstatePlot convertEstatePlot(dynamic estatePlotData) {
  // If it's already an EstatePlot, return it directly.
  if (estatePlotData is EstatePlot) {
    return estatePlotData;
  }
  // If it's a String, assume it's a JSON representation and parse it.
  if (estatePlotData is String) {
    if (estatePlotData.trim().isEmpty) {
      throw Exception('Failed to convert estatePlot: Provided string is empty.');
    }
    try {
      final Map<String, dynamic> jsonData = jsonDecode(estatePlotData);
      return EstatePlot.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to convert estatePlot: $e');
    }
  }
  // Otherwise, throw an error.
  throw Exception('Unexpected type for estatePlotData');
}



EstatePlot parseEstatePlot(String jsonString) {
  try {
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    return EstatePlot.fromJson(jsonData);
  } catch (e) {
    throw Exception('Failed to parse EstatePlot: $e');
  }
}
