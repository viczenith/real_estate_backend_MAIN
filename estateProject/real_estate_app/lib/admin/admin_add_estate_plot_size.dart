import 'package:flutter/material.dart';
import 'package:real_estate_app/admin/models/plot_size_number_model.dart';
import 'admin_layout.dart';
import 'package:real_estate_app/core/api_service.dart';

class AddEstatePlotSize extends StatefulWidget {
  final String token;
  const AddEstatePlotSize({required this.token, super.key});

  @override
  _AddEstatePlotSizeState createState() => _AddEstatePlotSizeState();
}

class _AddEstatePlotSizeState extends State<AddEstatePlotSize>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _plotSizeController = TextEditingController();

  late ApiService _apiService;
  List<AddPlotSize> _plotSizes = [];
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _loadData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuad,
      ),
    );
    _animationController.forward();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _fetchPlotSizes();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPlotSizes() async {
    try {
      List<AddPlotSize> sizes = await _apiService.fetchPlotSizes(widget.token);
      setState(() => _plotSizes = sizes);
    } catch (e) {
      _showErrorDialog('Failed to load plot sizes', e.toString());
    }
  }

  Future<void> _addPlotSize() async {
    if (_formKey.currentState?.validate() ?? false) {
      final plotSize = _plotSizeController.text.trim();
      setState(() => _isLoading = true);
      try {
        await _apiService.createPlotSize(plotSize, widget.token);
        _plotSizeController.clear();
        await _fetchPlotSizes();
        _showSuccessDialog('Plot Size Added', 'The plot size was successfully added.');
      } catch (e) {
        _showErrorDialog('Failed to create plot size', e.toString());
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deletePlotSize(int id) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.deletePlotSize(id, widget.token);
      await _fetchPlotSizes();
      _showSuccessDialog('Plot Size Deleted', 'The plot size was successfully removed.');
    } catch (e) {
      _showErrorDialog('Failed to delete plot size', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditDialog(AddPlotSize plotSize) async {
    final editController = TextEditingController(text: plotSize.size);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Plot Size'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            labelText: 'Plot Size',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _apiService.updatePlotSize(
                  plotSize.id, editController.text, widget.token);
                Navigator.pop(context);
                await _fetchPlotSizes();
                _showSuccessDialog('Update Successful', 'Plot size updated successfully.');
              } catch (e) {
                Navigator.pop(context);
                _showErrorDialog('Update Failed', e.toString());
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog(String title, String message) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green.shade400,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showErrorDialog(String title, String error) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade400,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF6C5CE7).withOpacity(0.7)),
      labelStyle: TextStyle(color: Colors.grey.shade600),
      floatingLabelStyle: const TextStyle(color: Color(0xFF6C5CE7)),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8F9FF), Color(0xFFF3F4FF)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'Add Estate Plot Size',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D3436),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter plot sizes in any unit (e.g., 250 sqm, 0.5 acre, 2 hectares). Dont edit/delete already allocated plot size.',
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _plotSizeController,
                      decoration: _inputDecoration(
                        label: 'Estate Plot Size', 
                        icon: Icons.aspect_ratio),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter plot size';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSubmitButton() {
    return Material(
      borderRadius: BorderRadius.circular(15),
      elevation: 5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF8477FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _addPlotSize,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Add Plot Size',
                      style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 0.5,
                        color: Colors.white),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPlotSizesList() {
    if (_isLoading && _plotSizes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'All Plot Sizes:',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _plotSizes.length,
          itemBuilder: (context, index) {
            final plotSize = _plotSizes[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: const Icon(Icons.aspect_ratio, color: Color(0xFF6C5CE7)),
                title: Text(plotSize.size),
                trailing: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditDialog(plotSize);
                          } else if (value == 'delete') {
                            _deletePlotSize(plotSize.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit')),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete')),
                        ],
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _plotSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Add Estate Plot Sizes',
      token: widget.token,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildFormContent(),
              _buildPlotSizesList(),
            ],
          ),
        ),
      ),
    );
  }
}




