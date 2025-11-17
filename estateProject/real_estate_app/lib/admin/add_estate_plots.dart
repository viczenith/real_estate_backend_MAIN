import 'dart:convert';
import 'package:flutter/material.dart';
import 'admin_layout.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/models/add_estate_plot_model.dart';

class AddEstatePlots extends StatefulWidget {
  final String token;

  const AddEstatePlots({Key? key, required this.token}) : super(key: key);

  @override
  _AddEstatePlotsState createState() => _AddEstatePlotsState();
}

class _AddEstatePlotsState extends State<AddEstatePlots> {
  final _formKey = GlobalKey<FormState>();
  final ApiService apiService = ApiService();

  List<Map<String, dynamic>> estateList = [];
  List<PlotSizeData> allPlotSizes = [];
  List<PlotNumber> allPlotNumbers = [];
  Set<int> allocatedPlotIds = {};
  Set<int> currentPlotNumbers = {};

  int? selectedEstate;
  Map<int, bool> selectedPlotSizes = {};
  Map<int, TextEditingController> unitControllers = {};
  Set<int> selectedPlotNumbers = {};

  bool isEstatesLoading = true;
  bool isDetailsLoading = false;
  bool detailsLoaded = false;

  @override
  void initState() {
    super.initState();
    fetchEstates();
  }

  @override
  void dispose() {
    for (var controller in unitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showMessageModal(String message, bool isSuccess) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 300),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSuccess ? Icons.check_circle : Icons.error_outline,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 60,
                ),
                SizedBox(height: 16),
                Text(
                  isSuccess ? 'Success!' : 'Error!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green : Colors.red,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? Colors.green : Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child:
                      Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> fetchEstates() async {
    setState(() => isEstatesLoading = true);
    try {
      final response = await apiService.fetchEstates(token: widget.token);
      setState(() {
        estateList = List<Map<String, dynamic>>.from(response);
        isEstatesLoading = false;
      });
    } catch (e) {
      setState(() => isEstatesLoading = false);
      if (mounted) {
        _showMessageModal('Error fetching estates: ${e.toString()}', false);
      }
    }
  }

  Future<void> fetchEstatePlotDetails(int estateId) async {
    setState(() {
      isDetailsLoading = true;
      detailsLoaded = false;
      allPlotSizes = [];
      allPlotNumbers = [];
      allocatedPlotIds.clear();
      currentPlotNumbers.clear();
      selectedPlotSizes.clear();
      selectedPlotNumbers.clear();
      unitControllers.forEach((key, controller) => controller.clear());
    });

    try {
      // Since fetchAddEstatePlotDetails now returns an EstatePlotDetails object,
      // we can assign it directly.
      final EstatePlotDetails details =
          await apiService.fetchAddEstatePlotDetails(
        estateId: estateId,
        token: widget.token,
      );

      setState(() {
        allPlotSizes = details.allPlotSizes;
        allPlotNumbers = details.allPlotNumbers;
        allocatedPlotIds = details.allocatedPlotIds.toSet();
        currentPlotNumbers = details.currentPlotNumbers.toSet();

        for (var size in details.currentPlotSizes) {
          selectedPlotSizes[size.id] = true;
          unitControllers[size.id] =
              TextEditingController(text: size.units.toString());
        }
        selectedPlotNumbers = currentPlotNumbers.toSet();
        detailsLoaded = true;
      });
    } catch (e) {
      if (mounted) {
        _showMessageModal('Error fetching details: ${e.toString()}', false);
      }
    } finally {
      setState(() => isDetailsLoading = false);
    }
  }

  Future<void> submitEstatePlot() async {
    if (!_formKey.currentState!.validate()) return;

    int totalUnits = 0;
    selectedPlotSizes.forEach((id, selected) {
      if (selected) {
        totalUnits += int.tryParse(unitControllers[id]?.text ?? '') ?? 0;
      }
    });

    if (totalUnits != selectedPlotNumbers.length) {
      _showMessageModal(
          "Total units must match the number of selected plot numbers", false);
      return;
    }

    final payload = {
      'estate': selectedEstate,
      'plot_sizes': allPlotSizes
          .where((size) => selectedPlotSizes[size.id] ?? false)
          .map((size) => {
                'plot_size_id': size.id,
                'units': int.tryParse(unitControllers[size.id]?.text ?? '') ??
                    0,
              })
          .toList(),
      'plot_numbers': selectedPlotNumbers.toList(),
    };

    try {
      final response = await apiService.submitEstatePlot(
        token: widget.token,
        payload: payload,
      );

      _showMessageModal(response['message'], true);
      if (selectedEstate != null) {
        fetchEstatePlotDetails(selectedEstate!);
      }
    } catch (e) {
      String errorMessage;
      try {
        final errorJson = json.decode(e.toString());
        errorMessage = errorJson['error'] ??
            errorJson['non_field_errors']?.first?.toString() ??
            e.toString();
      } catch (_) {
        errorMessage = e.toString();
      }
      _showMessageModal('Submission failed: $errorMessage', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: "Add Estate Plot",
      token: widget.token,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        body: isEstatesLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(16.0),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: Offset(0, 8),
                        blurRadius: 20,
                      )
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              Text("Add Estate Plot",
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87)),
                              SizedBox(height: 8),
                              Text("Fill in the details to add/update the estate plot.",
                                  style: TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        ),
                        SizedBox(height: 30),
                        DropdownButtonFormField<int>(
                          decoration: InputDecoration(
                            labelText: "Select Estate",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          value: selectedEstate,
                          items: estateList.map((estate) {
                            return DropdownMenuItem<int>(
                              value: estate['id'],
                              child: Text(estate['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedEstate = value;
                                detailsLoaded = false;
                              });
                              fetchEstatePlotDetails(value);
                            }
                          },
                          validator: (value) =>
                              value == null ? "Please select an estate" : null,
                        ),
                        SizedBox(height: 30),
                        if (isDetailsLoading)
                          Center(child: CircularProgressIndicator())
                        else if (!detailsLoaded)
                          Container()
                        else ...[
                          Text("Plot Sizes and Units",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          Column(
                            children: allPlotSizes.map((size) {
                              final isSelected = selectedPlotSizes[size.id] ?? false;
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 5.0),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          selectedPlotSizes[size.id] = value ?? false;
                                          if (value == false) {
                                            unitControllers[size.id]?.clear();
                                          } else {
                                            unitControllers.putIfAbsent(
                                                size.id,
                                                () => TextEditingController(text: '0'));
                                          }
                                        });
                                      },
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(child: Text(size.size)),
                                    SizedBox(width: 10),
                                    Container(
                                      width: 100,
                                      child: TextFormField(
                                        controller: unitControllers[size.id],
                                        enabled: isSelected,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          hintText: "Units",
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10)),
                                        ),
                                        validator: (value) {
                                          if (isSelected && (value == null || value.isEmpty)) {
                                            return "Required";
                                          }
                                          if (isSelected && (int.tryParse(value ?? '') ?? 0) <= 0) {
                                            return "Invalid units";
                                          }
                                          return null;
                                        },
                                      ),
                                    )
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 30),
                          Text("Plot Numbers",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: allPlotNumbers.map((plot) {
                              final isAllocated = allocatedPlotIds.contains(plot.id);
                              final isCurrent = currentPlotNumbers.contains(plot.id);
                              final isSelected = selectedPlotNumbers.contains(plot.id);

                              return FilterChip(
                                label: Text(plot.number),
                                selected: isSelected,
                                onSelected: isAllocated && !isCurrent 
                                    ? null 
                                    : (selected) {
                                        setState(() {
                                          if (selected) {
                                            selectedPlotNumbers.add(plot.id);
                                          } else {
                                            selectedPlotNumbers.remove(plot.id);
                                          }
                                        });
                                      },
                                selectedColor: Colors.deepPurple,
                                backgroundColor: isAllocated && !isCurrent 
                                    ? Colors.blueGrey 
                                    : Colors.green[200],
                                labelStyle: TextStyle(
                                    color: isAllocated && !isCurrent 
                                        ? Colors.black 
                                        : Colors.white),
                                checkmarkColor: Colors.white,
                              );
                            }).toList(),
                          ),
                          SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: submitEstatePlot,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                backgroundColor: Colors.deepPurple,
                              ),
                              child: Text("Add Estate Plots",
                                  style: TextStyle(fontSize: 16, color: Colors.white)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}


