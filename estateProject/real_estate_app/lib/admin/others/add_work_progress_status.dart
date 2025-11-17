import 'package:flutter/material.dart';
import 'package:real_estate_app/core/api_service.dart';

class AddWorkProgressStatusModal extends StatefulWidget {
  final String estateName;
  final String estateId;
  final String token;

  const AddWorkProgressStatusModal({
    super.key,
    required this.estateName,
    required this.estateId,
    required this.token,
  });

  @override
  _AddWorkProgressStatusModalState createState() => _AddWorkProgressStatusModalState();
}

class _AddWorkProgressStatusModalState extends State<AddWorkProgressStatusModal>
    with SingleTickerProviderStateMixin {
  final _progressController = TextEditingController();
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
  }

  Future<void> _submitForm() async {
    final progressText = _progressController.text.trim();
    if (progressText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a progress update')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ApiService().updateWorkProgress(
        estateId: widget.estateId,
        progressStatus: progressText,
        token: widget.token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress updated successfully')),
      );
      Navigator.pop(context, true); // Indicate success
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update progress: $e')),
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
                      'Update Work Progress for',
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
                  controller: _progressController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Progress Status',
                    hintText: 'Enter progress update...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    _progressController.dispose();
    super.dispose();
  }
}