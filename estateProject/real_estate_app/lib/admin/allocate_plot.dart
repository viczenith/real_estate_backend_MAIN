import 'package:flutter/material.dart';
import 'admin_layout.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/models/plot_allocation_model.dart';

class AllocatePlot extends StatefulWidget {
  final String token;
  const AllocatePlot({required this.token, Key? key}) : super(key: key);

  @override
  _AllocatePlotState createState() => _AllocatePlotState();
}

class _AllocatePlotState extends State<AllocatePlot> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _selectedClientId;
  String? _selectedEstateId;
  String? _selectedPlotSizeUnitId;
  String _paymentType = 'full';
  bool _showPlotNumber = true;

  PlotNumberPlotAllocation? _selectedPlotNumber;

  List<ClientForPlotAllocation> _clients = [];
  List<EstateForPlotAllocation> _estates = [];
  List<PlotSizeUnit> _plotSizes = [];
  List<PlotNumberPlotAllocation> _plotNumbers = [];
  bool _isLoading = false;

  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuad));

    _animationController.forward();
    _loadInitialData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final clients = await _apiService.fetchClientsForPlotAllocation(widget.token);
      final estates = await _apiService.fetchEstatesForPlotAllocation(widget.token);
      setState(() {
        _clients = clients;
        _estates = estates;
      });
    } catch (e) {
      _showErrorDialog('Initialization Error', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPlotData(String estateId) async {
    if (estateId.isEmpty) return;
    setState(() {
      _isLoading = true;
      _plotSizes = [];
      _plotNumbers = [];
      _selectedPlotNumber = null;
      _selectedPlotSizeUnitId = null;
    });
    try {
      final id = int.tryParse(estateId) ?? 0;
      if (id == 0) throw Exception('Invalid estate ID');
      final plotData = await _apiService.loadPlotsForPlotAllocation(id, widget.token);
      setState(() {
        _plotSizes = plotData.plotSizeUnits;
        _plotNumbers = plotData.plotNumbers.where((p) => p.isAvailable).toList();
      });
    } catch (e) {
      _showErrorDialog('Plot Data Error', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_paymentType == 'full' && _selectedPlotNumber == null) {
      _showErrorDialog('Validation Error', 'Please select a plot number for full payment');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _apiService.createAllocation(
        clientId: int.parse(_selectedClientId!),
        estateId: int.parse(_selectedEstateId!),
        plotSizeUnitId: int.parse(_selectedPlotSizeUnitId!),
        plotNumberId: _paymentType == 'full' ? _selectedPlotNumber!.id : null,
        paymentType: _paymentType,
        token: widget.token,
      );
      _showSuccessDialog();
      _resetForm();
    } catch (e) {
      _showErrorDialog('Allocation Failed', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedClientId = null;
      _selectedEstateId = null;
      _selectedPlotSizeUnitId = null;
      _selectedPlotNumber = null;
      _paymentType = 'full';
      _showPlotNumber = true;
      _plotSizes = [];
      _plotNumbers = [];
    });
  }

  // void _showSuccessDialog() => showDialog(
  //   context: context,
  //   builder: (_) => AlertDialog(
  //     title: const Text('Success'),
  //     content: const Text('Plot allocated successfully!'),
  //     actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')) ],
  //   ),
  // );

  void _showSuccessDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Success',
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, animation, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon(Icons.check_circle, color: Colors.green, size: 80),
                    Icon(Icons.check_circle, color: Color(0xFF6C5CE7), size: 80),
                    const SizedBox(height: 16),
                    Text(
                      'Success',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        // color: Colors.green,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Plot allocated successfully!',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        // backgroundColor: Colors.green,
                        backgroundColor: Color(0xFF6C5CE7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }


  void _showErrorDialog(String title, String message) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [ TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')) ],
    ),
  );

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF6C5CE7)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      hintStyle: TextStyle(color: Colors.grey[400]),
      labelStyle: TextStyle(color: Colors.grey[600]),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [ BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0,5)) ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text('Plot Allocation', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF2D3436))),
                    const SizedBox(height: 30),

                    // Client
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration(label: 'Registered Client', icon: Icons.person),
                      value: _selectedClientId,
                      items: _clients.map((c) => DropdownMenuItem(value: c.id.toString(), child: Text(c.fullName))).toList(),
                      onChanged: (v) => setState(() => _selectedClientId = v),
                      validator: (v) => v == null ? 'Please select a client' : null,
                    ),
                    const SizedBox(height: 20),

                    // Estate
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration(label: 'Estate Name', icon: Icons.landscape),
                      value: _selectedEstateId,
                      items: _estates.map((e) => DropdownMenuItem(value: e.id.toString(), child: Text(e.name))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedEstateId = v);
                        if (v != null) _loadPlotData(v);
                      },
                      validator: (v) => v == null ? 'Please select an estate' : null,
                    ),
                    const SizedBox(height: 20),

                    // Plot Size
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration(label: 'Plot Size', icon: Icons.aspect_ratio),
                      value: _selectedPlotSizeUnitId,
                      items: _plotSizes.map((u) {
                        final avail = u.availableUnits;
                        return DropdownMenuItem<String>(
                          value: u.id.toString(),
                          child: Text(
                            u.formattedSize,
                            style: TextStyle(color: avail > 0 ? Colors.black : Colors.grey),
                          ),
                          enabled: avail > 0,
                        );
                      }).toList(),
                      onChanged: (v) => v != null ? setState(() => _selectedPlotSizeUnitId = v) : null,
                      validator: (v) => v == null ? 'Please select a plot size' : null,
                    ),
                    const SizedBox(height: 20),

                    // Payment Type
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Type', style: TextStyle(color: Colors.grey.shade600)),
                        RadioListTile<String>(
                          title: const Text('Full Payment'),
                          value: 'full',
                          groupValue: _paymentType,
                          onChanged: (v) => setState(() {
                            _paymentType = v!;
                            _showPlotNumber = true;
                            _selectedPlotNumber = null;
                          }),
                        ),
                        RadioListTile<String>(
                          title: const Text('Part Payment'),
                          value: 'part',
                          groupValue: _paymentType,
                          onChanged: (v) => setState(() {
                            _paymentType = v!;
                            _showPlotNumber = false;
                            _selectedPlotNumber = null;
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Plot Number
                    if (_showPlotNumber && _plotNumbers.isNotEmpty)
                      DropdownButtonFormField<PlotNumberPlotAllocation>(
                        decoration: _inputDecoration(label: 'Plot Number', icon: Icons.numbers),
                        value: _selectedPlotNumber,
                        items: _plotNumbers.map((p) => DropdownMenuItem(value: p, child: Text(p.number))).toList(),
                        onChanged: (v) => setState(() => _selectedPlotNumber = v),
                        validator: (v) => _paymentType == 'full' && v == null ? 'Please select a plot number' : null,
                      ),
                    const SizedBox(height: 30),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Allocate Plot', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Plot Allocation',
      token: widget.token,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: _isLoading && _clients.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildFormContent(),
            ),
          ],
        ),
      ),
    );
  }
}
































