class EstateDetails {
  final String estateName;
  final String location;
  final String estateSize;
  final List<PlotSize> plotSizes;
  final List<Allocation> allocations;

  EstateDetails({
    required this.estateName,
    required this.location,
    required this.estateSize,
    required this.plotSizes,
    required this.allocations,
  });

  factory EstateDetails.fromJson(Map<String, dynamic> json) {
    return EstateDetails(
      estateName: json['estate_name'] ?? 'Unknown Estate',
      location: json['location'] ?? 'No location',
      estateSize: json['estate_size'] ?? 'N/A',
      plotSizes: (json['plot_sizes'] as List<dynamic>? ?? [])
          .map((e) => PlotSize.fromJson(e))
          .toList(),
      allocations: (json['allocations'] as List<dynamic>? ?? [])
          .map((e) => Allocation.fromJson(e))
          .toList(),
    );
  }
}

class PlotSize {
  final String size;
  final int allocated;
  final int totalUnits;
  final int reserved;

  PlotSize({
    required this.size,
    required this.allocated,
    required this.totalUnits,
    required this.reserved,
  });

  factory PlotSize.fromJson(Map<String, dynamic> json) {
    return PlotSize(
      size: json['plot_size'] ?? 'N/A',
      allocated: json['allocated'] ?? 0,
      totalUnits: json['total_units'] ?? 0,
      reserved: json['reserved'] ?? 0,
    );
  }
}

// Define Allocation based on EstateAllocationSerializer output
class Allocation {
  // Add fields based on your serializer
  final String client;
  final String plotNumber;

  Allocation({required this.client, required this.plotNumber});

  factory Allocation.fromJson(Map<String, dynamic> json) {
    return Allocation(
      client: json['client'] ?? 'Unknown',
      plotNumber: json['plot_number'] ?? 'N/A',
    );
  }
}