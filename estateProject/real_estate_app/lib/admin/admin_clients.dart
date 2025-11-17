import 'package:flutter/material.dart';
import 'package:real_estate_app/admin/admin_client_profile.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'admin_layout.dart';

// Client Model
class Client {
  final String id;
  final String name;
  final String email;
  final String phone;

  const Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'].toString(),
      name: json['full_name'],
      email: json['email'],
      phone: json['phone'],
    );
  }
}

class AdminClients extends StatefulWidget {
  final String token;
  const AdminClients({required this.token, Key? key}) : super(key: key);

  @override
  State<AdminClients> createState() => _AdminClientsState();
}

class _AdminClientsState extends State<AdminClients> {
  final TextEditingController _searchController = TextEditingController();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  bool _sortAscending = true;
  int _sortColumnIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _searchController.addListener(_filterClients);
  }

  void _fetchClients() async {
    try {
      final data = await ApiService().fetchClients(widget.token);
      setState(() {
        _clients = data.map((json) => Client.fromJson(json)).toList();
        _filteredClients = _clients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading clients: $e')),
      );
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _clients.where((client) {
        return client.name.toLowerCase().contains(query) ||
            client.email.toLowerCase().contains(query) ||
            client.phone.contains(query);
      }).toList();
    });
  }

  void _sort<T extends Comparable>(
      int columnIndex, bool ascending, T Function(Client) getField) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _filteredClients.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        return ascending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
    });
  }

  DataColumn _buildDataColumn<T extends Comparable>(
      String label, T Function(Client) getField,
      {required int columnIndex}) {
    return DataColumn(
      label: Text(label),
      onSort: (int columnIndex, bool ascending) =>
          _sort<T>(columnIndex, ascending, getField),
    );
  }

  DataRow _buildClientRow(Client client, int index) {
    return DataRow(
      color: MaterialStateProperty.resolveWith<Color>(
        (states) => index.isEven
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      ),
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(client.name, style: const TextStyle(fontWeight: FontWeight.w500))),
        DataCell(Text(client.email)),
        DataCell(Text(client.phone)),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editClient(client),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteClient(client),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editClient(Client client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientProfilePage(
          token: widget.token,
          clientId: int.parse(client.id),
        ),
      ),
    );
  }

  void _deleteClient(Client client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text('Are you sure you want to delete ${client.name}?'),
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
        await ApiService().deleteClient(widget.token, client.id);
        setState(() {
          _clients.removeWhere((c) => c.id == client.id);
          _filteredClients = _clients;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${client.name} deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete ${client.name}: $e')),
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
        hintText: 'Search clients...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No clients found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Clients List',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        Text(
          'Total: ${_filteredClients.length}',
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
      pageTitle: 'Clients',
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
                    child: _filteredClients.isEmpty
                        ? _buildEmptyState()
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                sortColumnIndex: _sortColumnIndex,
                                sortAscending: _sortAscending,
                                headingRowColor: MaterialStateProperty.resolveWith<Color>(
                                  (states) => Theme.of(context).colorScheme.surfaceContainerHighest,
                                ),
                                columns: [
                                  _buildDataColumn<String>('No.', (client) => client.id, columnIndex: 0),
                                  _buildDataColumn<String>('Name', (client) => client.name, columnIndex: 1),
                                  _buildDataColumn<String>('Email', (client) => client.email, columnIndex: 2),
                                  _buildDataColumn<String>('Phone', (client) => client.phone, columnIndex: 3),
                                  const DataColumn(label: Text('Actions')),
                                ],
                                rows: List<DataRow>.generate(
                                  _filteredClients.length,
                                  (index) => _buildClientRow(_filteredClients[index], index),
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
