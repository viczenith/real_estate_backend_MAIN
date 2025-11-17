import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/models/add_plot_size.dart'; // Contains PlotSize model

class AddPrototypeModal extends StatefulWidget {
  final String estateId;
  final String estateName;
  final String token;

  const AddPrototypeModal({
    Key? key,
    required this.estateId,
    required this.estateName,
    required this.token,
  }) : super(key: key);

  @override
  _AddPrototypeModalState createState() => _AddPrototypeModalState();
}

class _AddPrototypeModalState extends State<AddPrototypeModal>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  String? _selectedPlotSizeId;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  List<PlotSize> _plotSizes = [];
  bool _isLoading = true;
  bool _isUploading = false;

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
      final plotSizes = await ApiService().getPlotSizesForEstate(
        estateId: widget.estateId,
        token: widget.token,
      );
      setState(() {
        _plotSizes = plotSizes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load plot sizes: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowCompression: true,
    );
    if (result != null) {
      setState(() => _selectedImage = File(result.files.single.path!));
    }
  }

  Future<void> _submitForm() async {
    if (_selectedImage == null ||
        _selectedPlotSizeId == null ||
        _titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await ApiService().uploadEstatePrototype(
        estateId: widget.estateId,
        plotSizeId: _selectedPlotSizeId!,
        prototypeImage: _selectedImage!,
        title: _titleController.text,
        description: _descriptionController.text,
        token: widget.token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prototype uploaded successfully')),
      );
      Navigator.pop(context, true); // Return success indicator
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload prototype: $e')),
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
                        'Upload Prototypes for',
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
                  // Plot Sizes Dropdown
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_plotSizes.isEmpty)
                    const Text('No plot sizes available for this estate')
                  else
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedPlotSizeId,
                        decoration: InputDecoration(
                          labelText: 'Plot Size',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: _plotSizes
                            .map((size) => DropdownMenuItem(
                                  value: size.id,
                                  child: Text(size.size),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedPlotSizeId = value),
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Image Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: _selectedImage != null
                              ? const Color(0xFF6A11CB)
                              : Colors.grey[300]!,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_outlined,
                            size: 40,
                            color: _selectedImage != null
                                ? const Color(0xFF6A11CB)
                                : Colors.grey[400],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedImage != null
                                ? 'Image selected'
                                : 'Tap to upload prototype image',
                            style: TextStyle(
                              color: _selectedImage != null
                                  ? const Color(0xFF6A11CB)
                                  : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_selectedImage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _selectedImage!.path.split('/').last,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => setState(() => _selectedImage = null),
                      child: const Text('Remove image', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Description Field
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                            ? const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              )
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
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
