import 'package:flutter/material.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/models/add_amenities_model.dart';

class AddAmenityModal extends StatefulWidget {
  final String estateName;
  final String estateId;
  final String token;

  const AddAmenityModal({
    Key? key,
    required this.estateName,
    required this.estateId,
    required this.token,
  }) : super(key: key);

  @override
  _AddAmenityModalState createState() => _AddAmenityModalState();
}

class _AddAmenityModalState extends State<AddAmenityModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Amenity> _availableAmenities = [];
  List<String> _selectedAmenities = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
    _fetchAvailableAmenities();
  }

  Future<void> _fetchAvailableAmenities() async {
    try {
      final amenities = await ApiService().getAvailableAmenities(widget.token);
      setState(() {
        _availableAmenities = amenities.map((data) => Amenity.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load amenities: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    try {
      await ApiService().updateEstateAmenities(
        estateId: widget.estateId,
        amenities: _selectedAmenities,
        token: widget.token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amenities updated successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update amenities: $e')),
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
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
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
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Column(
                      children: [
                        Text(
                          'Update Amenities for',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          widget.estateName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    // Amenities List
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_availableAmenities.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text('No amenities available'),
                      )
                    else
                      Column(
                        children: _availableAmenities.map((amenity) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  Icon(
                                    _getIconFromString(amenity.icon),
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      amenity.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              value: _selectedAmenities.contains(amenity.code),
                              onChanged: (bool? selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedAmenities.add(amenity.code);
                                  } else {
                                    _selectedAmenities.remove(amenity.code);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 25),
                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconFromString(String iconClass) {
    switch (iconClass) {
      case 'fa-parking':
        return Icons.local_parking;
      case 'fa-swimming-pool':
        return Icons.pool;
      case 'fa-wifi':
        return Icons.wifi;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
