class Estate {
  final String id;
  final String name;
  final String location;
  final String estateSize;
  final String titleDeed;
  final List<ProgressStatus> progressStatus;
  final List<EstateAmenitie> estateAmenities;
  final List<EstateLayout> estateLayouts;
  final List<EstateFloorPlan> floorPlans;
  final List<EstatePrototype> prototypes;
  final EstateMap? estateMap;

  Estate({
    required this.id,
    required this.name,
    required this.location,
    required this.estateSize,
    required this.titleDeed,
    required this.progressStatus,
    required this.estateAmenities,
    required this.estateLayouts,
    required this.floorPlans,
    required this.prototypes,
    this.estateMap,
  });

  factory Estate.fromJson(Map<String, dynamic> json) {
    return Estate(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      location: json['location'] ?? '',
      estateSize: json['estate_size'] ?? '',
      titleDeed: json['title_deed'] ?? '',
      progressStatus: (json['progress_status'] as List? ?? [])
          .map((e) => ProgressStatus.fromJson(e))
          .toList(),
      estateAmenities: (json['estate_amenity'] as List? ?? [])
          .map((e) => EstateAmenitie.fromJson(e))
          .toList(),
      estateLayouts: (json['estate_layout'] as List? ?? [])
          .map((e) => EstateLayout.fromJson(e))
          .toList(),
      floorPlans: (json['floor_plans'] as List? ?? [])
          .map((e) => EstateFloorPlan.fromJson(e))
          .toList(),
      prototypes: (json['prototypes'] as List? ?? [])
          .map((e) => EstatePrototype.fromJson(e))
          .toList(),
      estateMap: json['map'] != null ? EstateMap.fromJson(json['map']) : null,
    );
  }
}

class ProgressStatus {
  final String id;
  final String progressStatus;
  final DateTime timestamp;

  ProgressStatus({
    required this.id,
    required this.progressStatus,
    required this.timestamp,
  });

  factory ProgressStatus.fromJson(Map<String, dynamic> json) {
    return ProgressStatus(
      id: json['id'].toString(),
      progressStatus: json['progress_status'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class EstateAmenitie {
  final String id;
  final List<String> amenities;
  final List<Map<String, String>> amenitiesDisplay;

  EstateAmenitie({
    required this.id,
    required this.amenities,
    required this.amenitiesDisplay,
  });

  factory EstateAmenitie.fromJson(Map<String, dynamic> json) {
    return EstateAmenitie(
      id: json['id'].toString(),
      amenities: (json['amenities'] as List? ?? []).cast<String>(),
      amenitiesDisplay: (json['amenities_display'] as List? ?? [])
          .map((e) => {
                'name': e['name']?.toString() ?? '',
                'icon': e['icon']?.toString() ?? ''
              })
          .toList(),
    );
  }
}

class EstateLayout {
  final String id;
  final String layoutImageUrl;

  EstateLayout({
    required this.id,
    required this.layoutImageUrl,
  });

  factory EstateLayout.fromJson(Map<String, dynamic> json) {
    return EstateLayout(
      id: json['id'].toString(),
      layoutImageUrl: json['layout_image_url'] ?? '',
    );
  }
}

class EstateFloorPlan {
  final String id;
  final Map<String, dynamic> plotSize; // Nested object expected
  final String floorPlanImageUrl;
  final String planTitle;
  final DateTime dateUploaded;

  EstateFloorPlan({
    required this.id,
    required this.plotSize,
    required this.floorPlanImageUrl,
    required this.planTitle,
    required this.dateUploaded,
  });

  factory EstateFloorPlan.fromJson(Map<String, dynamic> json) {
    return EstateFloorPlan(
      id: json['id'].toString(),
      plotSize: json['plot_size'] is Map ? json['plot_size'] : {},
      floorPlanImageUrl: json['floor_plan_image_url'] ?? '',
      planTitle: json['plan_title'] ?? '',
      dateUploaded: DateTime.parse(json['date_uploaded']),
    );
  }
}

class EstatePrototype {
  final String id;
  final Map<String, dynamic> plotSize; // Nested object expected
  final String prototypeImageUrl;
  final String title;
  final String description;
  final DateTime dateUploaded;

  EstatePrototype({
    required this.id,
    required this.plotSize,
    required this.prototypeImageUrl,
    required this.title,
    required this.description,
    required this.dateUploaded,
  });

  factory EstatePrototype.fromJson(Map<String, dynamic> json) {
    return EstatePrototype(
      id: json['id'].toString(),
      plotSize: json['plot_size'] is Map ? json['plot_size'] : {},
      prototypeImageUrl: json['prototype_image_url'] ?? '',
      title: json['Title'] ?? '',
      description: json['Description'] ?? '',
      dateUploaded: DateTime.parse(json['date_uploaded']),
    );
  }
}

class EstateMap {
  final String id;
  final double latitude;
  final double longitude;
  final String? googleMapLink;
  final String generatedGoogleMapLink;

  EstateMap({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.googleMapLink,
    required this.generatedGoogleMapLink,
  });

  factory EstateMap.fromJson(Map<String, dynamic> json) {
    double parseCoordinate(dynamic value) {
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      } else if (value is num) {
        return value.toDouble();
      }
      return 0.0;
    }
    return EstateMap(
      id: json['id'].toString(),
      latitude: parseCoordinate(json['latitude']),
      longitude: parseCoordinate(json['longitude']),
      googleMapLink: json['google_map_link'],
      generatedGoogleMapLink: json['map_link'] ?? '',
    );
  }
}
