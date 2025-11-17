import 'package:flutter/material.dart';
import 'client_sidebar.dart';

class ClientRequestProperty extends StatefulWidget {
  const ClientRequestProperty({super.key, required String token});

  @override
  _ClientRequestPropertyState createState() => _ClientRequestPropertyState();
}

class _ClientRequestPropertyState extends State<ClientRequestProperty>
    with SingleTickerProviderStateMixin {
  bool isSidebarOpen = false;
  late AnimationController _sidebarController;
  // ignore: unused_field
  late Animation<double> _sidebarAnimation;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? selectedEstate;
  String? selectedPlotSize;
  String? paymentType;
  bool isLoadingPlots = false;

  final List<String> estates = [
    "Dutchman Estate Phase 2",
    "Dutchman Estate Phase 1",
    "Lior & Eliora Court",
    "Florin City Estate",
  ];

  final Map<String, List<String>> estatePlotSizes = {
    "Dutchman Estate Phase 2": ["250 SQM", "350 SQM", "500 SQM"],
    "Dutchman Estate Phase 1": ["300 SQM", "400 SQM"],
    "Lior & Eliora Court": ["350 SQM", "500 SQM"],
    "Florin City Estate": ["400 SQM", "600 SQM"],
  };

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

  void updatePlotSizes(String estate) {
    setState(() {
      isLoadingPlots = true;
    });

    Future.delayed(Duration(seconds: 1), () {
      setState(() {
        selectedPlotSize = null;
        isLoadingPlots = false;
      });
    });
  }

  void submitRequest() {
    if (_formKey.currentState!.validate()) {
      if (selectedPlotSize == null || paymentType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please complete all fields"),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Property request submitted successfully!"),
          backgroundColor: Colors.green,
        ),
      );
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
                  "Request New Property",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 5),
                Text("Home / Request Property",
                    style: TextStyle(color: Colors.grey)),
                SizedBox(height: 20),

                // Animated Form Container
                AnimatedContainer(
                  duration: Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Estate Dropdown
                        buildDropdownField(
                          label: "Estate Name",
                          value: selectedEstate,
                          items: estates,
                          onChanged: (value) {
                            setState(() {
                              selectedEstate = value;
                              updatePlotSizes(value!);
                            });
                          },
                        ),

                        SizedBox(height: 15),

                        // Plot Size Dropdown
                        isLoadingPlots
                            ? CircularProgressIndicator()
                            : buildDropdownField(
                                label: "Estate Plot Size",
                                value: selectedPlotSize,
                                items: selectedEstate != null
                                    ? estatePlotSizes[selectedEstate] ?? []
                                    : [],
                                onChanged: (value) {
                                  setState(() {
                                    selectedPlotSize = value;
                                  });
                                },
                              ),

                        SizedBox(height: 15),

                        // Payment Type Radio Buttons
                        buildPaymentTypeSelection(),

                        SizedBox(height: 20),

                        // Submit Button
                        ElevatedButton(
                          onPressed: submitRequest,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 25),
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            "Send Request",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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

  /// 🔹 **Header Widget**
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
            "Lior & Eliora",
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

  /// 🔹 **Dropdown Field Widget**
  Widget buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  /// 🔹 **Payment Type Selection Widget**
  Widget buildPaymentTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Payment Type", style: TextStyle(fontWeight: FontWeight.bold)),
        Row(
          children: [
            Radio(
                value: "Full Payment",
                groupValue: paymentType,
                onChanged: (value) => setState(() => paymentType = value)),
            Text("Full Payment"),
            Radio(
                value: "Part Payment",
                groupValue: paymentType,
                onChanged: (value) => setState(() => paymentType = value)),
            Text("Part Payment"),
          ],
        ),
      ],
    );
  }
}
