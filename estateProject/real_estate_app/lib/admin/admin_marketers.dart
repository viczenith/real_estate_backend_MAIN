import 'package:flutter/material.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/admin_marketer_profile.dart';
// ignore: unused_import
import 'dart:convert';
import 'admin_layout.dart';

class Marketer {
  final String id;
  final String name;
  final String email;
  final String phone;

  const Marketer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory Marketer.fromJson(Map<String, dynamic> json) {
    return Marketer(
      id: json['id'].toString(),
      name: json['full_name'],
      email: json['email'],
      phone: json['phone'],
    );
  }
}

class AdminMarketers extends StatefulWidget {
  final String token;
  const AdminMarketers({required this.token, Key? key}) : super(key: key);

  @override
  State<AdminMarketers> createState() => _AdminMarketersState();
}

class _AdminMarketersState extends State<AdminMarketers> {
  final TextEditingController _searchController = TextEditingController();
  List<Marketer> _marketers = [];
  List<Marketer> _filteredMarketers = [];
  bool _sortAscending = true;
  int _sortColumnIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMarketers();
    _searchController.addListener(_filterMarketers);
  }

  void _fetchMarketers() async {
    try {
      final data = await ApiService().fetchMarketers(widget.token);
      setState(() {
        _marketers = data.map((json) => Marketer.fromJson(json)).toList();
        _filteredMarketers = _marketers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading marketers: $e')),
      );
    }
  }

  void _filterMarketers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMarketers = _marketers.where((marketer) {
        return marketer.name.toLowerCase().contains(query) ||
            marketer.email.toLowerCase().contains(query) ||
            marketer.phone.contains(query);
      }).toList();
    });
  }

  void _sort<T extends Comparable>(
      int columnIndex, bool ascending, T Function(Marketer) getField) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _filteredMarketers.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        return ascending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
    });
  }

  DataColumn _buildDataColumn<T extends Comparable>(
      String label, T Function(Marketer) getField,
      {required int columnIndex}) {
    return DataColumn(
      label: Text(label),
      onSort: (int columnIndex, bool ascending) =>
          _sort<T>(columnIndex, ascending, getField),
    );
  }

  DataRow _buildMarketerRow(Marketer marketer, int index) {
    return DataRow(
      color: MaterialStateProperty.resolveWith<Color>(
        (states) => index.isEven
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
      ),
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(
          marketer.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        )),
        DataCell(Text(marketer.email)),
        DataCell(Text(marketer.phone)),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editMarketer(marketer),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteMarketer(marketer),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No marketers found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  void _editMarketer(Marketer marketer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarketerProfilePage(
          token: widget.token,
          marketerId: int.parse(marketer.id),
        ),
      ),
    );
  }


  void _deleteMarketer(Marketer marketer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Marketer'),
        content: Text('Are you sure you want to delete ${marketer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().deleteMarketer(widget.token, marketer.id);
        setState(() {
          _marketers.removeWhere((m) => m.id == marketer.id);
          _filteredMarketers = _marketers;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${marketer.name} deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete ${marketer.name}: $e')),
        );
      }
    }
  }


  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        hintText: 'Search marketers...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Marketers List',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        Text(
          'Total: ${_filteredMarketers.length}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Marketers',
      token: widget.token,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildTableHeader(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _filteredMarketers.isEmpty
                        ? _buildEmptyState()
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                sortColumnIndex: _sortColumnIndex,
                                sortAscending: _sortAscending,
                                headingRowColor: MaterialStateProperty.resolveWith<Color>(
                                  (states) => Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                                columns: [
                                  _buildDataColumn<String>(
                                    'No.',
                                    (marketer) => marketer.id,
                                    columnIndex: 0,
                                  ),
                                  _buildDataColumn<String>(
                                    'Name',
                                    (marketer) => marketer.name,
                                    columnIndex: 1,
                                  ),
                                  _buildDataColumn<String>(
                                    'Email',
                                    (marketer) => marketer.email,
                                    columnIndex: 2,
                                  ),
                                  _buildDataColumn<String>(
                                    'Phone',
                                    (marketer) => marketer.phone,
                                    columnIndex: 3,
                                  ),
                                  const DataColumn(label: Text('Actions')),
                                ],
                                rows: List<DataRow>.generate(
                                  _filteredMarketers.length,
                                  (index) => _buildMarketerRow(_filteredMarketers[index], index),
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
