import 'package:flutter/material.dart';
import 'package:real_estate_app/admin/models/plot_size_number_model.dart';
import 'admin_layout.dart';
import 'package:real_estate_app/core/api_service.dart';

class AddEstatePlotNumber extends StatefulWidget {
  final String token;
  const AddEstatePlotNumber({required this.token, super.key});

  @override
  _AddEstatePlotNumberState createState() => _AddEstatePlotNumberState();
}

class _AddEstatePlotNumberState extends State<AddEstatePlotNumber>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _plotNumberController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late ApiService _apiService;
  List<AddPlotNumber> _plotNumbers = [];
  Map<String, List<AddPlotNumber>> _groupedPlotNumbers = {};
  List<String> _numberGroups = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String _searchQuery = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _scrollController.addListener(_scrollListener);
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

  @override
  void dispose() {
    _animationController.dispose();
    _plotNumberController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final numbers = await _apiService.fetchPlotNumbers(widget.token, page: _currentPage);
      if (!mounted) return;
      setState(() {
        _plotNumbers.addAll(numbers);
        _hasMore = numbers.length >= 50;
        _groupPlotNumbers();
      });
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to load plot numbers', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _groupPlotNumbers() {
    _groupedPlotNumbers.clear();
    for (var number in _plotNumbers) {
      if (number.number.isEmpty) continue;
      final firstChar = number.number[0].toUpperCase();
      _groupedPlotNumbers.putIfAbsent(firstChar, () => []);
      _groupedPlotNumbers[firstChar]!.add(number);
    }
    _numberGroups = _groupedPlotNumbers.keys.toList()..sort();
    for (var group in _numberGroups) {
      _groupedPlotNumbers[group]!.sort((a, b) => a.number.compareTo(b.number));
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange &&
        !_isLoading &&
        _hasMore) {
      setState(() => _currentPage++);
      _loadData();
    }
  }

  Future<void> _addPlotNumber() async {
    if (_formKey.currentState?.validate() ?? false) {
      final plotNumber = _plotNumberController.text.trim();
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        final newNumber = await _apiService.createPlotNumber(plotNumber, widget.token);
        if (!mounted) return;
        setState(() {
          _plotNumbers.insert(0, newNumber);
          _plotNumberController.clear();
          _groupPlotNumbers();
        });
        _showSuccessDialog('Success', 'Plot number added successfully');
      } catch (e) {
        if (mounted) {
          _showErrorDialog('Failed to add plot number', e.toString());
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _confirmDelete(AddPlotNumber plotNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete plot number ${plotNumber.number}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deletePlotNumber(plotNumber);
  }

  Future<void> _deletePlotNumber(AddPlotNumber plotNumber) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _apiService.deletePlotNumber(plotNumber.id, widget.token);
      if (!mounted) return;
      setState(() {
        _plotNumbers.removeWhere((n) => n.id == plotNumber.id);
        _groupPlotNumbers();
      });
      _showSuccessDialog('Success', 'Plot number deleted successfully');
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to delete plot number', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditDialog(AddPlotNumber plotNumber) async {
    final editController = TextEditingController(text: plotNumber.number);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Plot Number'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            labelText: 'Plot Number',
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
                // First update the server
                await _apiService.updatePlotNumber(
                    plotNumber.id, editController.text, widget.token);
                if (!mounted) return;
                Navigator.pop(context);
                
                // Then update the local state
                setState(() {
                  // Create a new instance with updated values
                  final updatedPlotNumber = AddPlotNumber(
                    id: plotNumber.id,
                    number: editController.text,
                    createdAt: plotNumber.createdAt,
                  );
                  
                  // Find and replace the old instance
                  final index = _plotNumbers.indexWhere((n) => n.id == plotNumber.id);
                  if (index != -1) {
                    _plotNumbers[index] = updatedPlotNumber;
                  }
                  
                  _groupPlotNumbers();
                });
                
                _showSuccessDialog('Success', 'Plot number updated successfully');
              } catch (e) {
                Navigator.pop(context);
                if (mounted) {
                  _showErrorDialog('Failed to update plot number', e.toString());
                }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade400, size: 60),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('OK', style: TextStyle(color: Colors.white)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade400, size: 60),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('OK', style: TextStyle(color: Colors.white)),
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
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildNumberGroup(String group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            group,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6C5CE7),
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.8,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: _groupedPlotNumbers[group]!.length,
          itemBuilder: (context, index) {
            final plotNumber = _groupedPlotNumbers[group]![index];
            return _buildPlotNumberCard(plotNumber);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPlotNumberCard(AddPlotNumber plotNumber) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: Colors.white,
      margin: EdgeInsets.symmetric(vertical: 15, horizontal: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.grey.shade50,
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  plotNumber.number,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                padding: EdgeInsets.zero,
                iconSize: 18,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18, color: Colors.blue),
                        SizedBox(width: 6),
                        Text('Edit', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 6),
                        Text('Delete', style: TextStyle(fontSize: 14, color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditDialog(plotNumber);
                  } else if (value == 'delete') {
                    _confirmDelete(plotNumber);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlotNumbersList() {
    if (_isLoading && _plotNumbers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search plot numbers...',
              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF6C5CE7)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: _plotNumbers.isEmpty && !_isLoading
              ? const Center(
                  child: Text(
                    'No plot numbers found',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _numberGroups.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < _numberGroups.length) {
                      final group = _numberGroups[index];
                      final filteredNumbers = _groupedPlotNumbers[group]!
                          .where((n) => n.number.toLowerCase().contains(_searchQuery))
                          .toList();
                      if (filteredNumbers.isEmpty) return const SizedBox.shrink();
                      return _buildNumberGroup(group);
                    } else {
                      return _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox.shrink();
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 60),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add Plot Number',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D3436),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter plot numbers like RG A001, B102, etc. \n Dont edit/delete already allocated plot number.',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _plotNumberController,
                    decoration: _inputDecoration(
                        label: 'Plot Number', icon: Icons.numbers),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter plot number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _addPlotNumber,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C5CE7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Add Plot Number',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Add Estate Plot Numbers',
      token: widget.token,
      child: Column(
        children: [
          // Form Section - Takes only needed space
          _buildFormContent(),
          
          // List Section - Takes remaining space
          Expanded(
            child: _buildPlotNumbersList(),
          ),
        ],
      ),
    );
  }
}


