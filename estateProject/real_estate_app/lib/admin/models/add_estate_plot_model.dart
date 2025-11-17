// class EstatePlotDetails {
//   final List<PlotSizeData> allPlotSizes;
//   final List<PlotNumber> allPlotNumbers;
//   final List<int> allocatedPlotIds;
//   final List<PlotSizeData> currentPlotSizes;
//   final List<int> currentPlotNumbers;

//   EstatePlotDetails({
//     required this.allPlotSizes,
//     required this.allPlotNumbers,
//     required this.allocatedPlotIds,
//     required this.currentPlotSizes,
//     required this.currentPlotNumbers,
//   });

//   factory EstatePlotDetails.fromJson(Map<String, dynamic> json) {
//     return EstatePlotDetails(
//       allPlotSizes: _parsePlotSizes(json['all_plot_sizes']),
//       allPlotNumbers: _parsePlotNumbers(json['all_plot_numbers']),
//       allocatedPlotIds: _parseIds(json['allocated_plot_ids']),
//       currentPlotSizes: _parseCurrentSizes(json['current_plot_sizes']),
//       currentPlotNumbers: _parseIds(json['current_plot_numbers']),
//     );
//   }

//   static List<PlotSizeData> _parsePlotSizes(dynamic data) {
//     return (data as List<dynamic>)
//         .map((item) => PlotSizeData(
//               id: item['id'] as int? ?? 0,
//               size: item['size'] as String? ?? '',
//               units: 0,
//             ))
//         .toList();
//   }

//   static List<PlotNumber> _parsePlotNumbers(dynamic data) {
//     return (data as List<dynamic>)
//         .map((item) => PlotNumber(
//               id: item['id'] as int? ?? 0,
//               number: item['number'] as String? ?? '',
//             ))
//         .toList();
//   }

//   static List<int> _parseIds(dynamic data) {
//     return (data as List<dynamic>)
//         .map((id) => id as int? ?? 0)
//         .toList();
//   }

//   static List<PlotSizeData> _parseCurrentSizes(dynamic data) {
//     return (data as List<dynamic>)
//         .map((item) => PlotSizeData(
//               id: item['plot_size__id'] as int? ?? 0,
//               size: item['plot_size__size'] as String? ?? '',
//               units: item['total_units'] as int? ?? 0,
//             ))
//         .toList();
//   }
// }

// class PlotSizeData {
//   final int id;
//   final String size;
//   final int units;

//   PlotSizeData({required this.id, required this.size, required this.units});
// }

// class PlotNumber {
//   final int id;
//   final String number;

//   PlotNumber({required this.id, required this.number});
// }



class EstatePlotDetails {
  final List<PlotSizeData> allPlotSizes;
  final List<PlotNumber> allPlotNumbers;
  final List<int> allocatedPlotIds;
  final List<PlotSizeData> currentPlotSizes;
  final List<int> currentPlotNumbers;

  EstatePlotDetails({
    required this.allPlotSizes,
    required this.allPlotNumbers,
    required this.allocatedPlotIds,
    required this.currentPlotSizes,
    required this.currentPlotNumbers,
  });

  factory EstatePlotDetails.fromJson(Map<String, dynamic> json) {
    return EstatePlotDetails(
      allPlotSizes: _parsePlotSizes(json['all_plot_sizes']),
      allPlotNumbers: _parsePlotNumbers(json['all_plot_numbers']),
      allocatedPlotIds: _parseIds(json['allocated_plot_ids']),
      currentPlotSizes: _parseCurrentSizes(json['current_plot_sizes']),
      currentPlotNumbers: _parseIds(json['current_plot_numbers']),
    );
  }

  static List<PlotSizeData> _parsePlotSizes(dynamic data) {
    return (data as List<dynamic>)
        .map((item) => PlotSizeData(
              id: item['id'] as int? ?? 0,
              size: item['size'] as String? ?? '',
              units: 0,
            ))
        .toList();
  }

  static List<PlotNumber> _parsePlotNumbers(dynamic data) {
    return (data as List<dynamic>)
        .map((item) => PlotNumber(
              id: item['id'] as int? ?? 0,
              number: item['number'] as String? ?? '',
            ))
        .toList();
  }

  static List<int> _parseIds(dynamic data) {
    return (data as List<dynamic>)
        .map((id) => id as int? ?? 0)
        .toList();
  }

  static List<PlotSizeData> _parseCurrentSizes(dynamic data) {
    return (data as List<dynamic>)
        .map((item) => PlotSizeData(
              id: item['plot_size__id'] as int? ?? 0,
              size: item['plot_size__size'] as String? ?? '',
              units: item['total_units'] as int? ?? 0,
            ))
        .toList();
  }
}

class PlotSizeData {
  final int id;
  final String size;
  final int units;

  PlotSizeData({required this.id, required this.size, required this.units});
}

class PlotNumber {
  final int id;
  final String number;

  PlotNumber({required this.id, required this.number});
}


class ApiException implements Exception {
  final String message;
  final String details;
  final int statusCode;

  ApiException({
    required this.message,
    required this.details,
    required this.statusCode,
  });

  @override
  String toString() => '$message: $details';
}

