class AdminDashboardData {
  final int totalClients;
  final int totalMarketers;
  final int totalAllocations;
  final int pendingAllocations;
  final List<EstateData> estateAllocations;

  AdminDashboardData({
    required this.totalClients,
    required this.totalMarketers,
    required this.totalAllocations,
    required this.pendingAllocations,
    required this.estateAllocations,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    var estatesJson = json['estate_allocations'] as List;
    List<EstateData> estates = estatesJson.map((e) => EstateData.fromJson(e)).toList();
    return AdminDashboardData(
      totalClients: json['total_clients'],
      totalMarketers: json['total_marketers'],
      totalAllocations: json['total_allocations'],
      pendingAllocations: json['pending_allocations'],
      estateAllocations: estates,
    );
  }
}

class EstateData {
  final String estate;
  final String location;
  final String estateSize;
  final int allocations;
  final int pending;
  final int available;
  final List<PlotData> plots;

  EstateData({
    required this.estate,
    required this.location,
    required this.estateSize,
    required this.allocations,
    required this.pending,
    required this.available,
    required this.plots,
  });

  factory EstateData.fromJson(Map<String, dynamic> json) {
    var plotsJson = json['plots'] as List? ?? [];
    List<PlotData> plotList = plotsJson.map((e) => PlotData.fromJson(e)).toList();
    return EstateData(
      estate: json['estate'],
      location: json['location'],
      estateSize: json['estate_size'],
      allocations: json['allocations'],
      pending: json['pending'],
      available: json['available'],
      plots: plotList,
    );
  }
}

class PlotData {
  final String plotSize;
  final int totalUnits;
  final int allocated;
  final int reserved;
  final int available;

  PlotData({
    required this.plotSize,
    required this.totalUnits,
    required this.allocated,
    required this.reserved,
    required this.available,
  });

  factory PlotData.fromJson(Map<String, dynamic> json) {
    return PlotData(
      plotSize: json['plot_size'],
      totalUnits: json['total_units'],
      allocated: json['allocated'],
      reserved: json['reserved'],
      available: json['available'],
    );
  }
}
