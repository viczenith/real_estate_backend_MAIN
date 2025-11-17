import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:real_estate_app/core/api_service.dart';

class AddEstateLayoutModal extends StatefulWidget {
  final String estateName;
  final String estateId;
  final String token;

  const AddEstateLayoutModal({
    super.key,
    required this.estateName,
    required this.estateId,
    required this.token,
  });

  @override
  _AddEstateLayoutModalState createState() => _AddEstateLayoutModalState();
}

class _AddEstateLayoutModalState extends State<AddEstateLayoutModal>
    with SingleTickerProviderStateMixin {
  File? _selectedFile;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
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
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a layout image')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await ApiService().uploadEstateLayout(
        estateId: widget.estateId,
        layoutImage: _selectedFile!,
        token: widget.token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Layout uploaded successfully')),
      );
      Navigator.pop(context, true); // Indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload layout: $e')),
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
                      'Upload Estate Layout for',
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
                                'Tap to upload layout image',
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
                      child: const Text('Remove file', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
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
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}