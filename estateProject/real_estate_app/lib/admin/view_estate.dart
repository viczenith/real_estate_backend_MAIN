import 'package:flutter/material.dart';
import 'package:real_estate_app/admin/others/edit_estate_modal.dart';
import 'admin_layout.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:intl/intl.dart';

class ViewEstate extends StatefulWidget {
  final String token;
  const ViewEstate({required this.token, super.key});

  @override
  _ViewEstateState createState() => _ViewEstateState();
}

class _ViewEstateState extends State<ViewEstate> {
  late Future<List<EstateModel>> _estatesFuture;

  @override
  void initState() {
    super.initState();
    _estatesFuture = fetchEstates();
  }

  Future<List<EstateModel>> fetchEstates() async {
    try {
      List<dynamic> estatesJson = await ApiService().fetchEstates(token: widget.token);
      return estatesJson.map((json) => EstateModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Failed to load estates: $e");
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.landscape, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(
            'No Estates Found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add New Estate'),
            onPressed: () => Navigator.pushNamed(
              context, 
              '/add-estate',
              arguments: {
                'token': widget.token,
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableContent(List<EstateModel> estates) {
    return ListView.builder(
      itemCount: estates.length,
      itemBuilder: (context, index) {
        final estate = estates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      estate.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.deepPurple,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => EditEstateModal(
                                token: widget.token,
                                estateId: estate.id,
                                estate: estate,
                                onUpdate: () {
                                  setState(() {
                                    _estatesFuture = fetchEstates();
                                  });
                                },
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.green),
                          onPressed: () => Navigator.pushNamed(
                            context,
                            '/estate-allocation-details',
                            arguments: {
                              'estateId': estate.id,
                              'token': widget.token,
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                _buildInfoRow('Location', estate.location),
                _buildInfoRow('Estate Size', estate.estateSize),
                _buildInfoRow('Title Deed', estate.titleDeed),
                _buildInfoRow('Date Added', estate.formattedDate),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'View Estate',
      token: widget.token,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estate List',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.deepPurple.shade800,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: FutureBuilder<List<EstateModel>>(
                future: _estatesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load estates',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.red,
                                ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _estatesFuture = fetchEstates();
                              });
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasData) {
                    final estates = snapshot.data!;
                    return estates.isEmpty ? _buildEmptyState() : _buildTableContent(estates);
                  }
                  return _buildEmptyState();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EstateModel {
  final String id;
  final String name;
  final String location;
  final String estateSize;
  final String titleDeed;
  final String dateAdded;
  final String formattedDate;

  EstateModel({
    required this.id,
    required this.name,
    required this.location,
    required this.estateSize,
    required this.titleDeed,
    required this.dateAdded,
    required this.formattedDate,
  });

  factory EstateModel.fromJson(Map<String, dynamic> json) {
    // Parse and format the date
    String formattedDate = '';
    try {
      if (json['date_added'] != null) {
        DateTime date = DateTime.parse(json['date_added']);
        formattedDate = DateFormat('yyyy-MM-dd').format(date);
      }
    } catch (e) {
      formattedDate = 'Invalid date';
    }

    return EstateModel(
      id: json['id'].toString(),
      name: json['name'] ?? 'Unnamed Estate',
      location: json['location'] ?? 'No location',
      estateSize: json['estate_size']?.toString() ?? 'N/A',
      titleDeed: json['title_deed'] ?? 'No Title Deed',
      dateAdded: json['date_added'] ?? '',
      formattedDate: formattedDate,
    );
  }
}


