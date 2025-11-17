import 'package:flutter/material.dart';
import 'client_sidebar.dart';

class PropertyDetailsPage extends StatefulWidget {
  const PropertyDetailsPage({super.key, required String token});

  @override
  _PropertyDetailsPageState createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage>
    with SingleTickerProviderStateMixin {
  bool isSidebarOpen = false;
  late AnimationController _sidebarController;
  // ignore: unused_field
  late Animation<double> _sidebarAnimation;

  double _scaleFactor = 1.0;
  // ignore: unused_field
  final double _baseScaleFactor = 1.0;

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

  void zoomIn() {
    setState(() {
      _scaleFactor += 0.2;
    });
  }

  void zoomOut() {
    setState(() {
      _scaleFactor = (_scaleFactor - 0.2).clamp(1.0, 3.0);
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
                buildEstateHeader(),
                SizedBox(height: 20),
                buildProgressStatus(),
                SizedBox(height: 20),
                buildEstateAmenities(),
                SizedBox(height: 20),
                buildZoomableCard("Plot Size Prototype", "assets/prototype.jpg"),
                SizedBox(height: 20),
                buildZoomableCard("Estate Layout", "assets/layout.jpg"),
                SizedBox(height: 20),
                buildZoomableCard("250 SQM Building Plan", "assets/floor_plan.jpg"),
                SizedBox(height: 20),
                buildZoomableCard("Estate Location Map", "assets/map.jpg"),
                SizedBox(height: 30),
                buildBackButton(context),
              ],
            ),
          ),


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

  /// ✅ **Header (Same as Client Dashboard)**
  AppBar buildHeader() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 2,
      title: Row(
        children: [
          IconButton(
            icon: AnimatedIcon(
                icon: AnimatedIcons.menu_close,
                progress: _sidebarController),
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

  /// 🏡 **Estate Header Card**
  Widget buildEstateHeader() {
    return buildInfoCard([
      Text("Guzape Estate", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      SizedBox(height: 5),
      Row(children: [Icon(Icons.location_on, color: Colors.red), Text("Guzape, Abuja")]),
      SizedBox(height: 10),
      Text("Estate Size: 3.6 Hectares"),
      Text("Title Deed: Government Approved"),
      Text("Plot Size: 250 SQM"),
    ]);
  }

  /// 📈 **Progress Status Card**
  Widget buildProgressStatus() {
    return buildInfoCard([
      Text("Progress Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 10),
      buildStatusItem("05 Mar 2025 10:00 AM", "Road construction completed"),
      buildStatusItem("15 Feb 2025 02:30 PM", "Street lights installed"),
      buildStatusItem("01 Jan 2025 09:15 AM", "Drainage work started"),
    ]);
  }

  Widget buildStatusItem(String date, String status) {
    return ListTile(
      leading: Icon(Icons.check_circle, color: Colors.green),
      title: Text(status),
      subtitle: Text(date, style: TextStyle(color: Colors.grey)),
    );
  }

  /// 🏗 **Estate Amenities Card**
  Widget buildEstateAmenities() {
    return buildInfoCard([
      Text("Estate Amenities", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 10),
      buildAmenityItem(Icons.local_parking, "Ample Parking Space"),
      buildAmenityItem(Icons.security, "24/7 Security"),
      buildAmenityItem(Icons.wifi, "High-Speed Internet"),
      buildAmenityItem(Icons.pool, "Swimming Pool"),
    ]);
  }

  Widget buildAmenityItem(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        SizedBox(width: 10),
        Text(title),
      ],
    );
  }

  /// 🔎 **Zoomable Image Card**
  Widget buildZoomableCard(String title, String imagePath) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: EdgeInsets.all(10), child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),

          /// 🔍 Interactive Zoomable Image
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 3.0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
              ),
            ),
          ),

          /// ➕ Zoom In and ➖ Zoom Out Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(onPressed: zoomOut, icon: Icon(Icons.remove, color: Colors.blue)),
              Text("Zoom", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(onPressed: zoomIn, icon: Icon(Icons.add, color: Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  /// **🔄 Reusable Info Card Widget**
  Widget buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  /// **🔙 Back Button**
  Widget buildBackButton(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.arrow_back),
        label: Text("Back to Property List"),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600]),
      ),
    );
  }
}
