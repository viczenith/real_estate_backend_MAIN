import 'package:flutter/material.dart';
import 'package:real_estate_app/core/api_service.dart';

class AddEstateMapModal extends StatefulWidget {
  final String estateName;
  final String estateId;
  final String token;

  const AddEstateMapModal({
    super.key,
    required this.estateName,
    required this.estateId,
    required this.token,
  });

  @override
  _AddEstateMapModalState createState() => _AddEstateMapModalState();
}

class _AddEstateMapModalState extends State<AddEstateMapModal>
    with SingleTickerProviderStateMixin {
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _mapLinkController = TextEditingController();
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
    _fetchCurrentMapData();
  }

  /// Fetches the current estate map data from the API and populates the form fields.
  Future<void> _fetchCurrentMapData() async {
    try {
      final mapData = await ApiService().getEstateMap(
        estateId: widget.estateId,
        token: widget.token,
      );
      if (mapData != null) {
        _latitudeController.text = mapData['latitude']?.toString() ?? '';
        _longitudeController.text = mapData['longitude']?.toString() ?? '';
        _mapLinkController.text = mapData['google_map_link'] ?? '';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load current map data: $e')),
      );
    }
  }

  /// Submits the form data to the API to update the estate map.
  Future<void> _submitForm() async {
    final latitude = _latitudeController.text.trim();
    final longitude = _longitudeController.text.trim();
    final mapLink = _mapLinkController.text.trim();

    if (latitude.isEmpty || longitude.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latitude and longitude are required')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ApiService().updateEstateMap(
        estateId: widget.estateId,
        latitude: latitude,
        longitude: longitude,
        googleMapLink: mapLink.isNotEmpty ? mapLink : null,
        token: widget.token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Map updated successfully')),
      );
      Navigator.pop(context, true); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update map: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Text(
                      'Update Estate Map for',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w300),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.estateName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _latitudeController,
                  decoration: InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _longitudeController,
                  decoration: InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _mapLinkController,
                  decoration: InputDecoration(
                    labelText: 'Google Map Link (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context), // Cancel button
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                          : const Text('Update', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapLinkController.dispose();
    super.dispose();
  }
}