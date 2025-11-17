import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/models/estate_details_model.dart';

class EstateDetailsPage extends StatefulWidget {
  final String estateId;
  final String token;

  const EstateDetailsPage({Key? key, required this.estateId, required this.token})
      : super(key: key);

  @override
  _EstateDetailsPageState createState() => _EstateDetailsPageState();
}

class _EstateDetailsPageState extends State<EstateDetailsPage> {
  late Future<Estate> _estateFuture;

  @override
  void initState() {
    super.initState();
    _estateFuture = ApiService().getEstateDetails(widget.estateId, widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estate Details',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade700, Colors.indigo.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FutureBuilder<Estate>(
        future: _estateFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red.shade700),
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(
              child: Text(
                'No data available',
                style: TextStyle(color: Colors.grey),
              ),
            );
          } else {
            final estate = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EstateHeader(estate: estate),
                  if (estate.progressStatus.isNotEmpty)
                    _ProgressStatusSection(progressStatus: estate.progressStatus),
                  if (estate.estateAmenities.isNotEmpty &&
                      estate.estateAmenities.first.amenities.isNotEmpty)
                    _AmenitiesSection(amenities: estate.estateAmenities.first),
                  if (estate.estateLayouts.isNotEmpty)
                    _LayoutSection(layout: estate.estateLayouts.first),
                  if (estate.floorPlans.isNotEmpty)
                    _FloorPlansSection(floorPlans: estate.floorPlans),
                  if (estate.prototypes.isNotEmpty)
                    _PrototypesSection(prototypes: estate.prototypes),
                  if (estate.estateMap != null) _MapSection(map: estate.estateMap!),
                  const SizedBox(height: 20),
                  _BackButton(),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class _EstateHeader extends StatelessWidget {
  final Estate estate;

  const _EstateHeader({required this.estate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.indigo.shade100, Colors.teal.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estate.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    estate.location,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.landscape,
              label: 'Estate Size',
              value: estate.estateSize,
            ),
            _InfoRow(
              icon: Icons.description,
              label: 'Title Deed',
              value: estate.titleDeed,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.teal.shade700),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _ProgressStatusSection extends StatelessWidget {
  final List<ProgressStatus> progressStatus;

  const _ProgressStatusSection({required this.progressStatus});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: progressStatus.length,
              itemBuilder: (context, index) {
                final status = progressStatus[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle, color: Colors.teal.shade700),
                    ),
                    title: Text(
                      DateFormat('d MMM, yyyy HH:mm').format(status.timestamp),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    subtitle: Text(
                      status.progressStatus,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AmenitiesSection extends StatelessWidget {
  final EstateAmenitie amenities;

  const _AmenitiesSection({required this.amenities});

  IconData _getIcon(String amenityCode) {
    switch (amenityCode) {
      case 'bi-shield-lock':
        return FontAwesomeIcons.shieldHalved;
      case 'bi-camera-video':
        return FontAwesomeIcons.camera;
      case 'bi-lightning-charge-fill':
        return FontAwesomeIcons.bolt;
      case 'bi-droplet-fill':
        return FontAwesomeIcons.droplet;
      case 'bi-building':
        return FontAwesomeIcons.building;
      case 'bi-water':
        return FontAwesomeIcons.waterLadder;
      case 'bi-barbell':
        return FontAwesomeIcons.dumbbell;
      case 'bi-trophy':
        return FontAwesomeIcons.football;
      case 'bi-emoji-smile':
        return FontAwesomeIcons.child;
      case 'bi-mortarboard':
        return FontAwesomeIcons.graduationCap;
      case 'bi-hospital':
        return FontAwesomeIcons.houseMedical;
      case 'bi-shop':
        return FontAwesomeIcons.shop;
      case 'bi-house':
        return FontAwesomeIcons.church;
      case 'bi-tree':
        return FontAwesomeIcons.tree;
      case 'bi-car-front-fill':
        return FontAwesomeIcons.squareParking;
      case 'bi-briefcase':
        return FontAwesomeIcons.buildingUser;
      case 'bi-wifi':
        return FontAwesomeIcons.wifi;
      case 'bi-house-door-fill':
        return FontAwesomeIcons.houseSignal;
      default:
        return FontAwesomeIcons.question;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estate Amenities',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: amenities.amenitiesDisplay.map((amenity) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon(
                        _getIcon(amenity['icon'] ?? ''),
                        size: 14,
                        color: Colors.indigo.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        amenity['name'] ?? '',
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutSection extends StatefulWidget {
  final EstateLayout layout;

  const _LayoutSection({required this.layout});

  @override
  __LayoutSectionState createState() => __LayoutSectionState();
}

class __LayoutSectionState extends State<_LayoutSection> {
  final TransformationController _transformationController = TransformationController();

  void _zoomIn() {
    _transformationController.value *= Matrix4.diagonal3Values(1.2, 1.2, 1.0);
  }

  void _zoomOut() {
    _transformationController.value *= Matrix4.diagonal3Values(0.8, 0.8, 1.0);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estate Layout',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.1,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.layout.layoutImageUrl,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade700),
                      ),
                    ),
                    errorWidget: (context, url, error) => Icon(
                      Icons.error,
                      color: Colors.red.shade700,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in_layout',
                  onPressed: _zoomIn,
                  backgroundColor: Colors.teal.shade700,
                  child: const Icon(Icons.zoom_in, color: Colors.white),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.small(
                  heroTag: 'zoom_out_layout',
                  onPressed: _zoomOut,
                  backgroundColor: Colors.teal.shade700,
                  child: const Icon(Icons.zoom_out, color: Colors.white),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.small(
                  heroTag: 'reset_layout',
                  onPressed: _resetZoom,
                  backgroundColor: Colors.indigo.shade700,
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FloorPlansSection extends StatelessWidget {
  final List<EstateFloorPlan> floorPlans;

  const _FloorPlansSection({required this.floorPlans});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Floor Plans',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: floorPlans.length,
              itemBuilder: (context, index) {
                final plan = floorPlans[index];
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 300,
                        child: _ZoomableImageWithControls(
                          imageUrl: plan.floorPlanImageUrl,
                          tagPrefix: 'floor_plan_$index',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.plotSize is Map ? plan.plotSize['size'] ?? '' : '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              plan.planTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PrototypesSection extends StatelessWidget {
  final List<EstatePrototype> prototypes;

  const _PrototypesSection({required this.prototypes});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prototypes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: prototypes.length,
              itemBuilder: (context, index) {
                final prototype = prototypes[index];
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 300,
                        child: _ZoomableImageWithControls(
                          imageUrl: prototype.prototypeImageUrl,
                          tagPrefix: 'prototype_$index',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prototype.title ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              prototype.description ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Plot Size: ${prototype.plotSize is Map ? prototype.plotSize['size'] : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('d MMM, yyyy').format(prototype.dateUploaded),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomableImageWithControls extends StatefulWidget {
  final String imageUrl;
  final String tagPrefix;

  const _ZoomableImageWithControls({
    required this.imageUrl,
    required this.tagPrefix,
  });

  @override
  __ZoomableImageWithControlsState createState() => __ZoomableImageWithControlsState();
}

class __ZoomableImageWithControlsState extends State<_ZoomableImageWithControls> {
  final TransformationController _transformationController = TransformationController();

  void _zoomIn() {
    _transformationController.value *= Matrix4.diagonal3Values(1.2, 1.2, 1.0);
  }

  void _zoomOut() {
    _transformationController.value *= Matrix4.diagonal3Values(0.8, 0.8, 1.0);
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          child: InteractiveViewer(
            transformationController: _transformationController,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.1,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: widget.imageUrl,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade700),
                ),
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.error,
                color: Colors.red.shade700,
              ),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: Row(
            children: [
              FloatingActionButton.small(
                heroTag: '${widget.tagPrefix}_zoom_in',
                onPressed: _zoomIn,
                backgroundColor: Colors.teal.shade700,
                child: const Icon(Icons.zoom_in, color: Colors.white),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                heroTag: '${widget.tagPrefix}_zoom_out',
                onPressed: _zoomOut,
                backgroundColor: Colors.teal.shade700,
                child: const Icon(Icons.zoom_out, color: Colors.white),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                heroTag: '${widget.tagPrefix}_reset',
                onPressed: _resetZoom,
                backgroundColor: Colors.indigo.shade700,
                child: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


class _MapSection extends StatelessWidget {
  final EstateMap map;

  const _MapSection({required this.map});

  Future<void> _launchMap(BuildContext context) async {
    final String url = map.generatedGoogleMapLink;
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No map link available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not launch map for URL: $url'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade100, Colors.teal.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 50, color: Colors.indigo.shade700),
                    const SizedBox(height: 10),
                    Text(
                      'Lat: ${map.latitude}, Lng: ${map.longitude}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _launchMap(context),
                icon: const Icon(Icons.map, size: 18, color: Colors.white),
                label: const Text(
                  'View on Google Maps',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back, size: 18, color: Colors.white),
        label: const Text(
          'Back to Estates',
          style: TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo.shade700,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}