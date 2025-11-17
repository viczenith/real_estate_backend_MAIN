import 'package:flutter/material.dart';
import 'client_sidebar.dart';

class ClientPropertyList extends StatefulWidget {
  const ClientPropertyList({super.key, required String token});

  @override
  _ClientPropertyListState createState() => _ClientPropertyListState();
}

class _ClientPropertyListState extends State<ClientPropertyList>
    with SingleTickerProviderStateMixin {
  bool isSidebarOpen = false;
  late AnimationController _sidebarController;
  // ignore: unused_field
  late Animation<double> _sidebarAnimation;

  final List<PropertyItem> properties = [
    PropertyItem(
      estateName: "Guzape Estate",
      paymentStatus: "Fully Paid",
      plotSize: "250 sqm",
      plotNumber: "COO2",
      datePurchased: "12-Feb-2025",
    ),
    PropertyItem(
      estateName: "Katampe Extension",
      paymentStatus: "Partly Paid",
      plotSize: "300 sqm",
      plotNumber: "Reserved",
      datePurchased: "01-Jan-2025",
    ),
    PropertyItem(
      estateName: "Maitama Estate",
      paymentStatus: "Fully Paid",
      plotSize: "200 sqm",
      plotNumber: "B456",
      datePurchased: "21-Dec-2024",
    ),
    PropertyItem(
      estateName: "Gwarinpa Estate",
      paymentStatus: "Fully Paid",
      plotSize: "350 sqm",
      plotNumber: "C789",
      datePurchased: "10-Feb-2025",
    ),
    PropertyItem(
      estateName: "Wuse Estate",
      paymentStatus: "Partly Paid",
      plotSize: "400 sqm",
      plotNumber: "Reserved",
      datePurchased: "15-Jan-2025",
    ),
    PropertyItem(
      estateName: "Asokoro Estate",
      paymentStatus: "Partly Paid",
      plotSize: "150 sqm",
      plotNumber: "Reserved",
      datePurchased: "05-Feb-2025",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sidebarController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    _sidebarAnimation = Tween<double>(begin: -250, end: 0).animate(
      CurvedAnimation(parent: _sidebarController, curve: Curves.easeInOut),
    );
  }

  void toggleSidebar() {
    // Toggle immediately with a single click
    if (_sidebarController.status == AnimationStatus.completed ||
        _sidebarController.status == AnimationStatus.forward) {
      _sidebarController.reverse();
      setState(() {
        isSidebarOpen = false;
      });
    } else {
      _sidebarController.forward();
      setState(() {
        isSidebarOpen = true;
      });
    }
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: buildHeader(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "My Property List",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 5),
                Text("Home / Property List", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 20),
                buildPropertyTable(),
              ],
            ),
          ),

          // Sidebar Animation
          // AnimatedPositioned(
          //   duration: Duration(milliseconds: 300),
          //   left: isSidebarOpen ? 0 : -250, // Sidebar slides in & out
          //   top: 0,
          //   bottom: 0,
          //   width: 250, // Set sidebar width
          //   child: ClientSidebar(closeSidebar: toggleSidebar),
          // ),
        ],
      ),
    );
  }

  /// Header Widget
  AppBar buildHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      title: Row(
        children: [
          IconButton(
            icon: AnimatedIcon(
              icon: AnimatedIcons.menu_close,
              progress: _sidebarController,
            ),
            color: Colors.black87,
            onPressed: toggleSidebar,
          ),
          SizedBox(width: 10),
          Text(
            "Lior & Eliora Properties",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
            icon: Icon(Icons.notifications, color: Colors.blueAccent),
            onPressed: () {}),
        IconButton(
            icon: Icon(Icons.message, color: Colors.blueAccent),
            onPressed: () {}),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: CircleAvatar(
              backgroundImage: AssetImage('assets/profile.jpg')),
        ),
      ],
    );
  }

  /// Builds the property table using DataTable
  Widget buildPropertyTable() {
    return Container(
      margin: EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowColor:
              WidgetStateProperty.resolveWith((states) => Colors.blueGrey[50]),
          columns: [
            DataColumn(label: Text("No.", style: _colHeaderStyle)),
            DataColumn(label: Text("Estate Name", style: _colHeaderStyle)),
            DataColumn(label: Text("Payment Status", style: _colHeaderStyle)),
            DataColumn(label: Text("Plot Size", style: _colHeaderStyle)),
            DataColumn(label: Text("Plot Number", style: _colHeaderStyle)),
            DataColumn(label: Text("Date Purchased", style: _colHeaderStyle)),
            DataColumn(label: Text("Action", style: _colHeaderStyle)),
          ],
          rows: List.generate(properties.length, (index) {
            final property = properties[index];
            return DataRow(
              cells: [
                DataCell(Text((index + 1).toString(), style: _cellTextStyle)),
                DataCell(Text(property.estateName, style: _cellTextStyle)),
                DataCell(buildStatusTag(property.paymentStatus)),
                DataCell(Text(property.plotSize, style: _cellTextStyle)),
                DataCell(buildPlotNumberCell(property.plotNumber)),
                DataCell(Text(property.datePurchased, style: _cellTextStyle)),
                DataCell(
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/property-details');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: Text("View Estate"),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// Returns a colored tag widget for Payment Status
  Widget buildStatusTag(String status) {
    Color bgColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case "fully paid":
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case "partly paid":
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Returns a styled text widget for the Plot Number based on its reserved status.
  Widget buildPlotNumberCell(String plotNumber) {
    Color bgColor;
    Color textColor;
    switch (plotNumber.toUpperCase()) {
      case "RESERVED":
        bgColor = Colors.yellow.withOpacity(0.2);
        textColor = Colors.yellow[800]!;
        break;
      default:
        bgColor = Colors.green.withOpacity(0.2);
        textColor = Colors.green[800]!;
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        plotNumber,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Common text styles
  final TextStyle _colHeaderStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  final TextStyle _cellTextStyle = TextStyle(
    fontSize: 14,
    color: Colors.black87,
  );
}

/// Data model for property items
class PropertyItem {
  final String estateName;
  final String paymentStatus;
  final String plotSize;
  final String plotNumber;
  final String datePurchased;

  PropertyItem({
    required this.estateName,
    required this.paymentStatus,
    required this.plotSize,
    required this.plotNumber,
    required this.datePurchased,
  });
}
