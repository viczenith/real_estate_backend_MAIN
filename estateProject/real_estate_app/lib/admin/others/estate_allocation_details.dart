// ignore: unused_import
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:real_estate_app/admin/admin_layout.dart';
import 'package:real_estate_app/admin/others/edit_estate_plot_modal.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'package:real_estate_app/admin/download_files/file_downloader.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:real_estate_app/admin/models/update_allocation_model.dart';
import 'package:real_estate_app/admin/others/update_allocation_modal.dart';
import 'package:real_estate_app/admin/others/add_layout.dart';
import 'package:real_estate_app/admin/others/add_prototypes.dart';
import 'package:real_estate_app/admin/others/add_floor_plan.dart';
import 'package:real_estate_app/admin/others/add_amenity.dart';
import 'package:real_estate_app/admin/others/add_work_progress_status.dart';
import 'package:real_estate_app/admin/others/add_estate_map.dart';
import 'package:real_estate_app/admin/others/estate_details.dart';

/// Custom Exception Class
class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

/// Model Classes for Type Safety
class EstateDetails {
  final String estateName;
  final String location;
  final String estateSize;
  final List<PlotSize> plotSizes;
  final List<PlotNumber> plotNumbers;
  final List<Allocation> allocations;

  EstateDetails({
    required this.estateName,
    required this.location,
    required this.estateSize,
    required this.plotSizes,
    required this.plotNumbers,
    required this.allocations,
  });

  factory EstateDetails.fromJson(Map<String, dynamic> json) {
    return EstateDetails(
      estateName: json['estate_name']?.toString() ?? 'Unknown Estate',
      location: json['location']?.toString() ?? 'No location',
      estateSize: json['estate_size']?.toString() ?? 'N/A',
      plotSizes: (json['plot_sizes'] as List<dynamic>? ?? [])
          .map((e) => PlotSize.fromJson(e as Map<String, dynamic>))
          .toList(),
      plotNumbers: (json['plot_numbers'] as List<dynamic>? ?? [])
          .map((e) => PlotNumber.fromJson(e as Map<String, dynamic>))
          .toList(),
      allocations: (json['allocations'] as List<dynamic>? ?? [])
          .map((e) => Allocation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Allocation {
  final int id;
  final String client;
  final String clientId;
  final String plotSizeUnitId;
  final String plotSize;
  final String paymentType;
  final String plotNumberId;
  final String plotNumber;
  final String allocationDate;
  final bool isAllocated;

  Allocation({
    required this.id,
    required this.client,
    required this.clientId,
    required this.plotSizeUnitId,
    required this.plotSize,
    required this.paymentType,
    required this.plotNumberId,
    required this.plotNumber,
    required this.allocationDate,
    required this.isAllocated,
  });

  factory Allocation.fromJson(Map<String, dynamic> json) {
    String clientName = 'Unknown Client';
    String clientId = '0';
    if (json['client'] is Map<String, dynamic>) {
      clientName = json['client']['full_name']?.toString() ?? 'Unknown Client';
      clientId = json['client']['id']?.toString() ?? '0';
    } else {
      clientName = json['client']?.toString() ?? 'Unknown Client';
    }

    String plotSizeUnitId = 'N/A';
    String plotSize = 'N/A';
    if (json['plot_size_unit'] is Map<String, dynamic>) {
      plotSizeUnitId = json['plot_size_unit']['id']?.toString() ?? 'N/A';
      var plotSizeMap = json['plot_size_unit']['plot_size'];
      if (plotSizeMap is Map<String, dynamic>) {
        plotSize = plotSizeMap['size']?.toString() ?? 'N/A';
      } else {
        plotSize = plotSizeMap?.toString() ?? 'N/A';
      }
    } else {
      plotSize = json['plot_size_unit']?.toString() ?? 'N/A';
    }

    String plotNumberId = 'Not Allocated';
    String plotNumber = 'Not Allocated';
    if (json['plot_number'] is Map<String, dynamic>) {
      plotNumberId = json['plot_number']['id']?.toString() ?? 'Not Allocated';
      plotNumber = json['plot_number']['number']?.toString() ?? 'Not Allocated';
    } else {
      plotNumber = json['plot_number']?.toString() ?? 'Not Allocated';
    }

    String paymentType = json['payment_type_display']?.toString() ?? 'N/A';

    String rawDate = json['date_allocated']?.toString() ?? 'N/A';
    String formattedDate = 'N/A';
    if (rawDate != 'N/A') {
      try {
        DateTime dt = DateTime.parse(rawDate);
        formattedDate = DateFormat('dd-MMM-yyyy').format(dt);
      } catch (e) {
        formattedDate = rawDate;
      }
    }

    return Allocation(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      client: clientName,
      clientId: clientId,
      plotSizeUnitId: plotSizeUnitId,
      plotSize: plotSize,
      paymentType: paymentType,
      plotNumberId: plotNumberId,
      plotNumber: plotNumber,
      allocationDate: formattedDate,
      isAllocated: paymentType == 'Full Payment',
    );
  }
}

/// Main Page Widget for Viewing Estate Allocation Details
class EstateAllocationDetails extends StatefulWidget {
  final String token;
  final String estateId;
  final String estatePlot;
  

  const EstateAllocationDetails({
    required this.token,
    required this.estateId,
    required this.estatePlot,
    super.key,
  });

  @override
  _EstateAllocationDetailsState createState() => _EstateAllocationDetailsState();
}

class _EstateAllocationDetailsState extends State<EstateAllocationDetails> {
  EstateDetails? estateDetails;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  List<Allocation> filteredAllocations = [];

  @override
  void initState() {
    super.initState();
    _fetchEstateDetails();
  }

  @override
  void didUpdateWidget(EstateAllocationDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.estateId != oldWidget.estateId) {
      _fetchEstateDetails();
    }
  }

  Future<void> _fetchEstateDetails() async {
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = '';
    });
    try {
      final data = await ApiService().fetchEstateFullAllocationDetails(widget.estateId, widget.token);
      setState(() {
        estateDetails = EstateDetails.fromJson(data);
        filteredAllocations = estateDetails!.allocations;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  /// Generate CSV content from filteredAllocations.
  String generateCSV() {
    List<List<String>> rows = [];
    rows.add(['S/N', 'Client', 'Plot Size', 'Payment Type', 'Plot Number', 'Date']);
    for (int i = 0; i < filteredAllocations.length; i++) {
      final alloc = filteredAllocations[i];
      rows.add([
        '${i + 1}',
        alloc.client,
        alloc.plotSize,
        alloc.paymentType,
        alloc.plotNumber,
        alloc.allocationDate,
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  /// Download CSV
  Future<void> _downloadCSV() async {
    try {
      final estateName = estateDetails?.estateName ?? "Unknown Estate";
      String csv = generateCSV();
      final filename = 'Allocation_Report_for_${estateName.replaceAll(' ', '_')}.csv';
      await downloadCSV(filename, csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV downloaded successfully for $estateName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV download failed: $e')),
      );
    }
  }

  /// Generate a well-designed A4 PDF document for the allocation table.
  Future<void> _downloadPDF() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final logoData = await rootBundle.load("assets/logo.png");
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      final estateName = estateDetails?.estateName ?? "Unknown Estate";
      final generationTime = DateFormat("dd-MMM-yyyy").format(DateTime.now());

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: pw.BoxDecoration(
                gradient: pw.LinearGradient(
                  colors: [PdfColors.indigo, PdfColors.blueAccent],
                  begin: pw.Alignment.topLeft,
                  end: pw.Alignment.bottomRight,
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      image: pw.DecorationImage(
                        image: logoImage,
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Text(
                      'Allocation Report for $estateName',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          },
          footer: (context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 16),
              child: pw.Text(
                'Generated on $generationTime | Page ${context.pageNumber} of ${context.pagesCount}',
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            );
          },
          build: (context) {
            return [
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Text(
                  'Total Clients: ${filteredAllocations.length}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('S/N',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Client',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Plot Size',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Payment Type',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Plot Number',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Date',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...List.generate(filteredAllocations.length, (index) {
                    final alloc = filteredAllocations[index];
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 == 0 ? PdfColors.grey200 : PdfColors.white,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${index + 1}'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(alloc.client),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(alloc.plotSize),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(alloc.paymentType),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(alloc.plotNumber),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(alloc.allocationDate),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      final filename = 'Allocation_Report_for_${estateName.replaceAll(' ', '_')}.pdf';
      await downloadPDF(filename, bytes);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('PDF downloaded successfully for $estateName')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF download failed: $e')),
      );
    }
  }

  void _filterAllocations(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredAllocations = estateDetails!.allocations.where((alloc) {
        return alloc.client.toLowerCase().contains(lowerQuery) ||
            alloc.plotNumber.toLowerCase().contains(lowerQuery) ||
            alloc.paymentType.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Estate Allocation',
      token: widget.token,
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
              ? Center(child: Text(errorMessage))
              : estateDetails == null
                  ? const Center(child: Text('No estate details available'))
                  : Scaffold(
                      appBar: AppBar(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              estateDetails!.estateName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              'Plot Allocation',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: 'Download CSV',
                            onPressed: _downloadCSV,
                          ),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf),
                            tooltip: 'Download PDF',
                            onPressed: _downloadPDF,
                          ),
                        ],
                      ),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBreadcrumbs(),
                            const Gap(20),
                            _buildQuickActions(),
                            const Gap(24),
                            _buildEstateInfo(),
                            const Gap(24),
                            _buildPlotSizesAndNumbersCard(),
                            const Gap(24),
                            _buildSearchBar(),
                            const Gap(24),
                            _buildAllocationsList(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  /// UI Components
  Widget _buildBreadcrumbs() {
    return Row(
      children: [
        Text('Home', style: TextStyle(color: Colors.grey.shade600)),
        const Icon(Icons.chevron_right, size: 16),
        Text('Estate List', style: TextStyle(color: Colors.grey.shade600)),
        const Icon(Icons.chevron_right, size: 16),
        Text('Plot Allocation', style: TextStyle(color: Colors.blue.shade800)),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [

        // Add Layout
        ActionChip(
          avatar: const Icon(Icons.map, size: 18),
          label: const Text('Add Layout'),
          onPressed: () => showDialog(
            context: context,
            builder: (context) => AddEstateLayoutModal(
              estateName: estateDetails!.estateName,
              estateId: widget.estateId,
              token: widget.token,
            ),
          ).then((result) {
            if (result == true) {
              
              setState(() {});
            }
          }),
        ),

        // Add Amenities
        ActionChip(
          avatar: const Icon(Icons.emoji_food_beverage, size: 18),
          label: const Text('Add Amenities'),
          onPressed: () => showDialog(
            context: context,
            builder: (context) => AddAmenityModal(
              estateName: estateDetails!.estateName,
              estateId: widget.estateId,
              token: widget.token,
            ),
          ).then((result) {
            if (result == true) {
              
              setState(() {});
            }
          }),
        ),
        // _ActionChip(icon: Icons.emoji_food_beverage, label: 'Add Amenities'),
        
        // Add Prototypes
        ActionChip(
          avatar: const Icon(Icons.account_tree, size: 18),
          label: const Text('Add Prototypes'),
          onPressed: () => showDialog(
            context: context,
            builder: (context) => AddPrototypeModal(
              estateId: widget.estateId,
              estateName: estateDetails!.estateName,
              token: widget.token,
            ),
          ).then((result) {
            if (result == true) {
              setState(() {});
            }
          }),
        ),

        // Add Floor Plan
        ActionChip(
          avatar: const Icon(Icons.house, size: 18),
          label: const Text('Add Floor Plan'),
          onPressed: () => showDialog(
            context: context,
            builder: (context) => AddFloorPlanModal(
              estateId: widget.estateId,
              estateName: estateDetails!.estateName,
              token: widget.token,
            ),
          ).then((result) {
            if (result == true) {
              
              setState(() {});
            }
          }),
        ),
        // _ActionChip(icon: Icons.house, label: 'Add Floor Plans'),

        // Work Progress
        ActionChip(
          avatar: const Icon(Icons.construction, size: 18),
          label: const Text('Work Progress'),
          onPressed: () => showDialog(
            context: context,
            builder: (context) => AddWorkProgressStatusModal(
              estateId: widget.estateId,
              estateName: estateDetails!.estateName,
              token: widget.token,
            ),
          ).then((result) {
            if (result == true) {
              
              setState(() {});
            }
          }),
        ),
        
        // _ActionChip(icon: Icons.construction, label: 'Work Progress'),


        // Add Map
        ActionChip(
          avatar: const Icon(Icons.map, size: 18),
          label: const Text('Add Map'),
          onPressed: () => showDialog(
            context: context,
            builder: (context) => AddEstateMapModal(
              estateId: widget.estateId,
              estateName: estateDetails!.estateName,
              token: widget.token,
            ),
          ).then((result) {
            if (result == true) {
              
              setState(() {});
            }
          }),
        ),
        
        ActionChip(
          avatar: const Icon(Icons.photo_library),
          label: const Text('View Details'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EstateDetailsPage(
                  estateId: widget.estateId,
                  token: widget.token,
                ),
              ),
            );
          },
        ),

        // _ActionChip(icon: Icons.photo_library, label: 'View Details'),
      ],
    );
  }

  Widget _buildEstateInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estateDetails!.estateName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const Gap(4),
                Text(
                  estateDetails!.location,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const Gap(4),
            Row(
              children: [
                Icon(Icons.square_foot, size: 16, color: Colors.grey.shade600),
                const Gap(4),
                Text(
                  estateDetails!.estateSize,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlotSizesAndNumbersCard() {
    final List<PlotSize> plotSizes = estateDetails!.plotSizes;
    final List<PlotNumber> plotNumbers = estateDetails!.plotNumbers;
    return Stack(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plot Sizes & Units',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                ...plotSizes.map<Widget>((size) => PlotSizeCard(
                      size: size.size,
                      allocated: size.allocated,
                      total: size.totalUnits,
                      reserved: size.reserved,
                    )),
                const Gap(16),
                const Text(
                  'Plot Numbers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _buildPlotNumbers(plotNumbers),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => EditEstatePlotModal(
                  token: widget.token,
                  estateId: widget.estateId,
                  onUpdate: () {
                    // Refresh your estate plot data after update
                    setState(() {});
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlotNumbers(List<PlotNumber> plotNumbers) {
    if (plotNumbers.isEmpty) {
      return const Text('No plot numbers assigned for this estate.');
    }
    int allocatedCount = plotNumbers.where((num) => num.isAllocated).length;
    int totalCount = plotNumbers.length;
    int availableCount = totalCount - allocatedCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: plotNumbers
              .map<Widget>((num) => PlotNumberChip(
                    number: num.number,
                    isAllocated: num.isAllocated,
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatusIndicator(
              count: allocatedCount,
              total: totalCount,
              label: 'Allocated',
              color: Colors.green,
            ),
            const SizedBox(width: 16),
            _StatusIndicator(
              count: availableCount,
              total: totalCount,
              label: 'Available',
              color: Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search clients, plot numbers, or payment types...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () =>
              setState(() => filteredAllocations = estateDetails!.allocations),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onChanged: _filterAllocations,
    );
  }

  

  Widget _buildAllocationsList() {
    if (filteredAllocations.isEmpty) {
      return const Center(
        child: Text(
          'No allocations',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Clients: ${filteredAllocations.length}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateColor.resolveWith(
                (states) => Colors.grey.shade200),
            border: TableBorder.all(color: Colors.grey.shade300),
            columns: const [
              DataColumn(label: Text('S/N')),
              DataColumn(label: Text('Client')),
              DataColumn(label: Text('Plot Size')),
              DataColumn(label: Text('Payment Type')),
              DataColumn(label: Text('Plot Number')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Actions')),
            ],
            rows: filteredAllocations.asMap().entries.map((entry) {
              int index = entry.key;
              Allocation alloc = entry.value;
              return DataRow(cells: [
                DataCell(Text('${index + 1}')),
                DataCell(Text(alloc.client)),
                DataCell(Text(
                    alloc.plotSize.isNotEmpty ? alloc.plotSize : 'Not Assigned')),
                DataCell(Text(alloc.paymentType.isNotEmpty
                    ? alloc.paymentType
                    : 'Not Assigned')),
                DataCell(Text(alloc.plotNumber.isNotEmpty
                    ? alloc.plotNumber
                    : 'Not Assigned')),
                DataCell(Text(alloc.allocationDate)),
                DataCell(
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      // Create instances required for update
                      final currentClient = Client(
                        id: alloc.clientId,
                        fullName: alloc.client,
                      );
                      final currentEstate = Estate(
                        id: widget.estateId,
                        name: estateDetails!.estateName,
                      );
                      // Create a dummy PlotSizeUnit based on allocation data
                      final plotSizeUnit = PlotSizeUnit(
                        id: alloc.plotSizeUnitId,
                        plotSize: PlotSize(
                          id: alloc.plotSizeUnitId,
                          size: alloc.plotSize,
                          allocated: 0,
                          totalUnits: 0,
                          reserved: 0,
                        ),
                      );
                      // Try to find the associated PlotNumber from estateDetails (if available)
                      final plotNumber = estateDetails!.plotNumbers.firstWhere(
                        (pn) => pn.id == alloc.plotNumberId,
                        orElse: () => PlotNumber(
                          id: alloc.plotNumberId,
                          number: alloc.plotNumber,
                          isAllocated: alloc.isAllocated,
                        ),
                      );
                      // Prepare allocation update data
                      final allocationForUpdate = AllocationUpdate(
                        id: alloc.id.toString(),
                        client: currentClient,
                        estate: currentEstate,
                        plotSizeUnit: plotSizeUnit,
                        plotNumber: alloc.plotNumber == 'Not Assigned'
                            ? null
                            : plotNumber,
                        paymentType: alloc.paymentType.toLowerCase().contains('full')
                            ? 'full'
                            : 'part',
                      );
                      // Show the update screen (ensure UpdateAllocationScreen is implemented)
                      showDialog(
                        context: context,
                        builder: (context) => UpdateAllocationScreen(
                          allocation: allocationForUpdate,
                          clients: [currentClient],
                          estates: [currentEstate],
                          plotSizeUnits: estateDetails!.plotSizes
                              .map((ps) => PlotSizeUnit(id: ps.id, plotSize: ps))
                              .toList(),
                          plotNumbers: estateDetails!.plotNumbers,
                          token: widget.token,
                        ),
                      ).then((result) {
                        if (result == true) {
                          _fetchEstateDetails();
                        }
                      });
                    },
                  ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }



}


/// Custom Components
class PlotSizeCard extends StatelessWidget {
  final String size;
  final int allocated;
  final int total;
  final int reserved;

  const PlotSizeCard({
    super.key,
    required this.size,
    required this.allocated,
    required this.total,
    required this.reserved,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  size,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('$allocated/$total Allocated'),
              ],
            ),
            const Gap(8),
            Row(
              children: [
                _StatusDot(color: Colors.green, count: allocated),
                Text(' $allocated Allocated'),
                const Gap(16),
                _StatusDot(color: Colors.orange, count: reserved),
                Text(' $reserved Reserved'),
                const Spacer(),
                if (allocated == total)
                  Chip(
                    label: const Text('Fully Allocated'),
                    backgroundColor: Colors.green.shade100,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlotNumberChip extends StatelessWidget {
  final String number;
  final bool isAllocated;

  const PlotNumberChip({
    super.key,
    required this.number,
    required this.isAllocated,
  });

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(number),
      avatar: Icon(
        isAllocated ? Icons.lock : Icons.lock_open,
        size: 16,
      ),
      backgroundColor: isAllocated ? Colors.green.shade100 : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionChip({required this.icon, required this.label, required Null Function() onPressed});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      onPressed: () {
        // Implement action logic if needed
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final int count;

  const _StatusDot({required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final int count;
  final int total;
  final String label;
  final Color color;

  const _StatusIndicator({
    required this.count,
    required this.total,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatusDot(color: color, count: count),
        const Gap(4),
        Text(
          '$count/$total $label',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}