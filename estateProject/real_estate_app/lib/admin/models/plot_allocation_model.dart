class EstatePlot {
  final List<PlotSizeUnit> plotSizeUnits;
  final List<PlotNumberPlotAllocation> plotNumbers;

  EstatePlot({
    required this.plotSizeUnits,
    required this.plotNumbers,
  });

  factory EstatePlot.fromJson(Map<String, dynamic> json) {
    return EstatePlot(
      plotSizeUnits: (json['plot_size_units'] as List)
          .map((e) => PlotSizeUnit.fromJson(e))
          .toList(),
      plotNumbers: (json['plot_numbers'] as List)
          .map((e) => PlotNumberPlotAllocation.fromJson(e))
          .toList(),
    );
  }
}


class PlotAllocationResponse {
  final List<PlotSizeUnit> plotSizeUnits;
  final List<PlotNumberPlotAllocation> plotNumbers;

  PlotAllocationResponse({
    required this.plotSizeUnits,
    required this.plotNumbers,
  });

  factory PlotAllocationResponse.fromJson(Map<String, dynamic> json) {
    // Handle the case where the API might return the data in a nested structure
    final plotSizeUnits = (json['plot_size_units'] as List<dynamic>? ?? [])
        .map((e) => PlotSizeUnit.fromJson(e as Map<String, dynamic>))
        .toList();

    final plotNumbers = (json['plot_numbers'] as List<dynamic>? ?? [])
        .map((e) => PlotNumberPlotAllocation.fromJson(e as Map<String, dynamic>))
        .toList();

    return PlotAllocationResponse(
      plotSizeUnits: plotSizeUnits,
      plotNumbers: plotNumbers,
    );
  }
}


class PlotSizeUnit {
  final int id;
  final String size;
  final int totalUnits;
  final int fullAllocations;
  final int reservedUnits;
  final int availableUnits;

  PlotSizeUnit({
    required this.id,
    required this.size,
    required this.totalUnits,
    required this.fullAllocations,
    required this.reservedUnits,
    required this.availableUnits,
  });

  factory PlotSizeUnit.fromJson(Map<String, dynamic> json) {
    return PlotSizeUnit(
      id: json['id'] as int,
      size: json['size'] as String,
      totalUnits: json['total_units'] as int,
      fullAllocations: json['full_allocations'] as int,
      reservedUnits: json['reserved_units'] as int,
      availableUnits: json['available_units'] as int,
    );
  }

  String get formattedSize =>
      '$size ($availableUnits/$totalUnits available)';
}


class PlotNumberPlotAllocation {
  final int id;
  final String number;
  final bool isAvailable;

  PlotNumberPlotAllocation({
    required this.id,
    required this.number,
    required this.isAvailable,
  });

  factory PlotNumberPlotAllocation.fromJson(Map<String, dynamic> json) {
    return PlotNumberPlotAllocation(
      id: json['id'] as int? ?? 0,
      number: json['number'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }
}

class ClientForPlotAllocation {
  final int id;
  final String fullName;
  final String email;
  final String phone;

  ClientForPlotAllocation({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
  });

  factory ClientForPlotAllocation.fromJson(Map<String, dynamic> json) {
    return ClientForPlotAllocation(
      id: json['id'] as int? ?? 0,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
    );
  }
}

class EstateForPlotAllocation {
  final int id;
  final String name;
  final String location;

  EstateForPlotAllocation({
    required this.id,
    required this.name,
    required this.location,
  });

  factory EstateForPlotAllocation.fromJson(Map<String, dynamic> json) {
    return EstateForPlotAllocation(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
    );
  }
}


