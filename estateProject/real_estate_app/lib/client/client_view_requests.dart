import 'package:flutter/material.dart';
// import 'client_sidebar.dart';

// ignore: use_key_in_widget_constructors
class ClientViewRequests extends StatefulWidget {
  const ClientViewRequests({super.key, required String token});


  @override
  _ClientViewRequestsState createState() => _ClientViewRequestsState();
}

class _ClientViewRequestsState extends State<ClientViewRequests>
    with SingleTickerProviderStateMixin {
  bool isSidebarOpen = false;
  late AnimationController _sidebarController;
  // ignore: unused_field
  late Animation<double> _sidebarAnimation;

  // Sample request data (Replace with actual API data)
  final List<RequestItem> requests = [
    RequestItem(
      estate: "Dutchman Estate",
      plotSize: "250 SQM",
      paymentType: "Installment",
      dateSent: "10-Mar-2025",
    ),
    RequestItem(
      estate: "Lior & Eliora Court",
      plotSize: "350 SQM",
      paymentType: "Full Payment",
      dateSent: "08-Feb-2025",
    ),
    RequestItem(
      estate: "Florin City Estate",
      plotSize: "500 SQM",
      paymentType: "Installment",
      dateSent: "01-Jan-2025",
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
    setState(() {
      isSidebarOpen = !isSidebarOpen;
      if (isSidebarOpen) {
        _sidebarController.forward();
      } else {
        _sidebarController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      appBar: buildHeader(),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "All Property Requests",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                SizedBox(height: 5),
                Text("Home / Property Requests",
                    style: TextStyle(color: Colors.grey)),
                SizedBox(height: 20),

                // 🌟 Requests Table
                buildRequestsTable(),
              ],
            ),
          ),

          // Sidebar Animation
          // AnimatedPositioned(
          //   duration: Duration(milliseconds: 300),
          //   left: isSidebarOpen ? 0 : -250,
          //   top: 0,
          //   bottom: 0,
          //   width: 250,
          //   child: ClientSidebar(closeSidebar: toggleSidebar),
          // ),
        ],
      ),
    );
  }

  /// ✅ **Header Widget**
  AppBar buildHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      title: Row(
        children: [
          IconButton(
            icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close, progress: _sidebarController),
            color: Colors.black87,
            onPressed: toggleSidebar,
          ),
          SizedBox(width: 10),
          Text(
            "Lior & Eliora Properties",
            style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold),
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
          child: CircleAvatar(backgroundImage: AssetImage('assets/logo.png')),
        ),
      ],
    );
  }

  /// 🏡 **Requests Table**
  Widget buildRequestsTable() {
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
            DataColumn(label: Text("#", style: _colHeaderStyle)),
            DataColumn(label: Text("Estate", style: _colHeaderStyle)),
            DataColumn(label: Text("Plot Size", style: _colHeaderStyle)),
            DataColumn(label: Text("Payment Type", style: _colHeaderStyle)),
            DataColumn(label: Text("Date Sent", style: _colHeaderStyle)),
          ],
          rows: List.generate(requests.length, (index) {
            final request = requests[index];
            return DataRow(
              cells: [
                DataCell(Text((index + 1).toString(), style: _cellTextStyle)),
                DataCell(Text(request.estate, style: _cellTextStyle)),
                DataCell(Text(request.plotSize, style: _cellTextStyle)),
                DataCell(Text(request.paymentType, style: _cellTextStyle)),
                DataCell(Text(request.dateSent, style: _cellTextStyle)),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// 🔹 **Table Header Style**
  final TextStyle _colHeaderStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  /// 🔹 **Table Cell Text Style**
  final TextStyle _cellTextStyle = TextStyle(
    fontSize: 14,
    color: Colors.black87,
  );
}

/// 📌 **Data Model for Requests**
class RequestItem {
  final String estate;
  final String plotSize;
  final String paymentType;
  final String dateSent;

  RequestItem({
    required this.estate,
    required this.plotSize,
    required this.paymentType,
    required this.dateSent,
  });
}
