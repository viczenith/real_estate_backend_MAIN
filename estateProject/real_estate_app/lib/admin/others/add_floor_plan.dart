import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/models/add_plot_size.dart';

class AddFloorPlanModal extends StatefulWidget {
  final String estateName;
  final String estateId;
  final String token;

  const AddFloorPlanModal({
    Key? key,
    required this.estateName,
    required this.estateId,
    required this.token,
  }) : super(key: key);

  @override
  _AddFloorPlanModalState createState() => _AddFloorPlanModalState();
}

class _AddFloorPlanModalState extends State<AddFloorPlanModal>
    with SingleTickerProviderStateMixin {
  File? _selectedFile;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isUploading = false;
  List<PlotSize> _plotSizes = [];
  String? _selectedPlotSizeId;
  final _planTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoadingPlotSizes = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
    _fetchPlotSizes();
  }

  Future<void> _fetchPlotSizes() async {
    try {
      final plotSizesData = await ApiService().getPlotSizesForEstate(
        estateId: widget.estateId,
        token: widget.token,
      );
      // Since the API returns List<PlotSize>, assign directly:
      setState(() {
        _plotSizes = plotSizesData;
        _isLoadingPlotSizes = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plot sizes: $e')),
      );
      setState(() => _isLoadingPlotSizes = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowCompression: true,
    );
    if (result != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submitForm() async {
    if (_selectedPlotSizeId == null ||
        _selectedFile == null ||
        _planTitleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await ApiService().uploadFloorPlan(
        estateId: widget.estateId,
        plotSizeId: _selectedPlotSizeId!,
        floorPlanImage: _selectedFile!,
        planTitle: _planTitleController.text,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        token: widget.token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Floor plan uploaded successfully')),
      );
      Navigator.pop(context, true); // Indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload floor plan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
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
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Column(
                    children: [
                      Text(
                        'Upload Floor Plan for',
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
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Plot Size Dropdown
                  if (_isLoadingPlotSizes)
                    const Center(child: CircularProgressIndicator())
                  else if (_plotSizes.isEmpty)
                    const Text('No plot sizes available for this estate')
                  else
                    DropdownButtonFormField<String>(
                      value: _selectedPlotSizeId,
                      decoration: const InputDecoration(
                        labelText: 'Plot Size',
                        border: OutlineInputBorder(),
                      ),
                      items: _plotSizes
                          .map((size) => DropdownMenuItem(
                                value: size.id,
                                child: Text(size.size),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedPlotSizeId = value),
                    ),
                  const SizedBox(height: 20),
                  // File Picker
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _selectedFile != null ? const Color(0xFF6A11CB) : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: _selectedFile != null
                          ? Image.file(_selectedFile!, fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  size: 40,
                                  color: _selectedFile != null ? const Color(0xFF6A11CB) : Colors.grey[400],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Tap to upload floor plan image',
                                  style: TextStyle(
                                    color: _selectedFile != null ? const Color(0xFF6A11CB) : Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  if (_selectedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedFile = null),
                        child: const Text(
                          'Remove file',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Title Field
                  TextFormField(
                    controller: _planTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Plan Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Description Field (Optional)
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton(
                        onPressed: _isUploading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isUploading
                            ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                            : const Text('Upload', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _planTitleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
