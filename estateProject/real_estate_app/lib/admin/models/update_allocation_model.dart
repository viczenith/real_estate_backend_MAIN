class Client {
  final String id;
  final String fullName;

  Client({required this.id, required this.fullName});
}

class Estate {
  final String id;
  final String name;

  Estate({required this.id, required this.name});
}

class PlotSize {
  final String id;
  final String size;
  final int allocated;
  final int totalUnits;
  final int reserved;

  PlotSize({
    required this.id,
    required this.size,
    required this.allocated,
    required this.totalUnits,
    required this.reserved,
  });

  factory PlotSize.fromJson(Map<String, dynamic> json) {
    String extractedId = 'N/A';
    String extractedSize = 'N/A';
    int allocated = 0;
    int totalUnits = 0;
    int reserved = 0;

    if (json['plot_size'] is Map<String, dynamic>) {
      extractedId = json['plot_size']['id']?.toString() ?? 'N/A';
      extractedSize = json['plot_size']['size']?.toString() ?? 'N/A';
    } else {
      extractedSize = json['plot_size']?.toString() ?? 'N/A';
    }

    allocated = (json['allocated'] is int) ? json['allocated'] : 0;
    totalUnits = (json['total_units'] is int) ? json['total_units'] : 0;
    reserved = (json['reserved'] is int) ? json['reserved'] : 0;

    return PlotSize(
      id: extractedId,
      size: extractedSize,
      allocated: allocated,
      totalUnits: totalUnits,
      reserved: reserved,
    );
  }
}

class PlotNumber {
  final String id;
  final String number;
  final bool isAllocated;

  PlotNumber({
    required this.id,
    required this.number,
    required this.isAllocated,
  });

  // factory PlotNumber.fromJson(Map<String, dynamic> json) {
  //   return PlotNumber(
  //     id: json['id']?.toString() ?? 'Not Allocated',
  //     number: json['number']?.toString() ?? 'Not Allocated',
  //     isAllocated: json['is_allocated'] is bool ? json['is_allocated'] : false,
  //   );
  // }

  factory PlotNumber.fromJson(Map<String, dynamic> json) {
    return PlotNumber(
      id: json['id']?.toString() ?? 'no-id', // Unique fallback if needed
      number: json['number']?.toString() ?? 'Not Allocated',
      isAllocated: json['is_allocated'] is bool ? json['is_allocated'] : false,
    );
  }
}

class PlotSizeUnit {
  final String id;
  final PlotSize plotSize;

  PlotSizeUnit({required this.id, required this.plotSize});
}

class AllocationUpdate {
  final String id;
  final Client client;
  final Estate estate;
  final PlotSizeUnit plotSizeUnit;
  final PlotNumber? plotNumber;
  final String paymentType;

  AllocationUpdate({
    required this.id,
    required this.client,
    required this.estate,
    required this.plotSizeUnit,
    this.plotNumber,
    required this.paymentType,
  });
}