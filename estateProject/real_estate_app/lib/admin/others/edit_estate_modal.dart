import 'package:flutter/material.dart';
import 'package:real_estate_app/admin/view_estate.dart';
import 'package:real_estate_app/core/api_service.dart';

class EditEstateModal extends StatefulWidget {
  final String token;
  final String estateId;
  final EstateModel estate;
  final Function() onUpdate;

  const EditEstateModal({
    required this.token,
    required this.estateId,
    required this.estate,
    required this.onUpdate,
    Key? key,
  }) : super(key: key);

  @override
  _EditEstateModalState createState() => _EditEstateModalState();
}

class _EditEstateModalState extends State<EditEstateModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _estateSizeController;
  String? _selectedTitleDeed;
  bool _isLoading = false;

  final List<String> _titleDeedOptions = [
    'FCDA RofO',
    'FCDA CofO',
    'AMAC',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.estate.name);
    _locationController = TextEditingController(text: widget.estate.location);
    _estateSizeController = TextEditingController(text: widget.estate.estateSize);
    _selectedTitleDeed = widget.estate.titleDeed;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _estateSizeController.dispose();
    super.dispose();
  }

  Future<void> _updateEstate() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final updatedData = {
          'name': _nameController.text,
          'location': _locationController.text,
          'estate_size': _estateSizeController.text,
          'title_deed': _selectedTitleDeed,
        };

        await ApiService().updateEstate(
          token: widget.token,
          estateId: widget.estateId,
          data: updatedData,
        );

        // Close the edit modal first
        Navigator.of(context).pop();
        
        // Show success modal
        _showResultModal(
          isSuccess: true,
          message: 'Estate updated successfully!',
        );

        widget.onUpdate();
      } catch (e) {
        // Show error modal
        _showResultModal(
          isSuccess: false,
          message: 'Failed to update estate: ${e.toString()}',
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showResultModal({required bool isSuccess, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              isSuccess ? 'Success' : 'Error',
              style: TextStyle(
                color: isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Edit Estate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Estate Name',
                    border: OutlineInputBorder(),
                    
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter estate name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter location';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _estateSizeController,
                  decoration: const InputDecoration(
                    labelText: 'Estate Size',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter estate size';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedTitleDeed,
                  decoration: const InputDecoration(
                    labelText: 'Title Deed',
                    border: OutlineInputBorder(),
                  ),
                  items: _titleDeedOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTitleDeed = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select title deed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  onPressed: _isLoading ? null : _updateEstate,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Update Estate',
                          style: TextStyle(fontSize: 16, color: Colors.white,),
                        ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

