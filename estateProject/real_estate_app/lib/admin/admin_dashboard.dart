import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'admin_layout.dart';
import 'package:real_estate_app/admin/models/admin_dashboard_data.dart';
import 'package:real_estate_app/core/api_service.dart';

class AdminDashboard extends StatefulWidget {
  final String token;
  const AdminDashboard({required this.token, super.key});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<AdminDashboardData> dashboardFuture;

  @override
  void initState() {
    super.initState();
    dashboardFuture = ApiService().fetchAdminDashboard(widget.token);
  }

  Widget _buildDashboardCards(AdminDashboardData data, bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      childAspectRatio: isMobile ? 1.1 : 1.3,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      padding: EdgeInsets.zero,
      children: [
        _buildStatCard(Icons.people_alt, "Total Clients", data.totalClients.toString(), Colors.blue),
        _buildStatCard(Icons.people_alt, "Total Marketers", data.totalMarketers.toString(), Colors.green),
        _buildStatCard(Icons.business_center, "Total Allocations", data.totalAllocations.toString(), Colors.orange),
        _buildStatCard(Icons.pending_actions, "Pending Allocations", data.pendingAllocations.toString(), Colors.red),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
            const SizedBox(height: 5),
            Text(value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationTrendsChart(AdminDashboardData data) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Estate Allocation Trends",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            SizedBox(
              height: 300, // Fixed height for chart
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(
                  labelRotation: -45,
                  title: AxisTitle(text: 'Estates'),
                ),
                primaryYAxis: NumericAxis(title: AxisTitle(text: 'Allocations')),
                plotAreaBorderWidth: 0,
                series: <CartesianSeries>[
                  AreaSeries<EstateData, String>(
                    dataSource: data.estateAllocations,
                    xValueMapper: (EstateData ed, _) => ed.estate,
                    yValueMapper: (EstateData ed, _) => ed.allocations,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF4154F1).withOpacity(0.4),
                        const Color(0xFF4154F1).withOpacity(0.1)
                      ],
                      stops: const [0.1, 0.9],
                    ),
                    borderColor: const Color(0xFF4154F1),
                    borderWidth: 2,
                    markerSettings: const MarkerSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstateReports(AdminDashboardData data) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Estate Allocation Report",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                if (data.estateAllocations.isEmpty)
                  _buildEmptyReport()
                else
                  ...data.estateAllocations.map((estate) => _buildEstateCard(estate)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyReport() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Text("No allocation data available", 
          style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildEstateCard(EstateData estate) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        children: [
          ListTile(
            title: Text(estate.estate, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Location: ${estate.location}", style: const TextStyle(color: Colors.green)),
                Text("Estate Size: ${estate.estateSize}", style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return _buildMobileTable(estate);
                }
                return _buildDesktopTable(estate);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(EstateData estate) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.5),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildTableHeader("Plot Size"),
            _buildTableHeader("Total Units"),
            _buildTableHeader("Allocated"),
            _buildTableHeader("Reserved"),
            _buildTableHeader("Available"),
          ],
        ),
        ...estate.plots.map((plot) {
          return TableRow(
            children: [
              _buildTableCell(plot.plotSize),
              _buildTableCell(plot.totalUnits.toString()),
              _buildTableCell(plot.allocated.toString(), color: Colors.green),
              _buildTableCell(plot.reserved.toString(), color: Colors.orange),
              _buildTableCell(plot.available.toString(), color: Colors.blue),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildMobileTable(EstateData estate) {
    return Column(
      children: estate.plots.map((plot) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Plot Size: ${plot.plotSize}", 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              _buildMobileRow("Total Units", plot.totalUnits.toString()),
              _buildMobileRow("Allocated", plot.allocated.toString(), Colors.green),
              _buildMobileRow("Reserved", plot.reserved.toString(), Colors.orange),
              _buildMobileRow("Available", plot.available.toString(), Colors.blue),
              const Divider(),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMobileRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(value, style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: color ?? Colors.black
          )),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text, 
          style: const TextStyle(
            fontWeight: FontWeight.bold, 
            color: Colors.blueGrey
          )),
    );
  }

  Widget _buildTableCell(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(text,
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: color ?? Colors.black
          ),
          textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Admin Dashboard',
      token: widget.token,
      child: FutureBuilder<AdminDashboardData>(
        future: dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final dashboardData = snapshot.data!;
          
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Home / ', 
                          style: TextStyle(color: Colors.grey.shade600)),
                      Text('Dashboard',
                          style: TextStyle(
                            color: Colors.deepPurple.shade600,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildDashboardCards(
                    dashboardData, 
                    MediaQuery.of(context).size.width < 600
                  ),
                  const SizedBox(height: 20),
                  _buildAllocationTrendsChart(dashboardData),
                  const SizedBox(height: 20),
                  _buildEstateReports(dashboardData),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}