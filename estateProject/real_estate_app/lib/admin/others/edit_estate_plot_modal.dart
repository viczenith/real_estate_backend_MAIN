// // ignore: unused_import
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:real_estate_app/core/api_service.dart';

// /// Custom Exception Class
// class ApiException implements Exception {
//   final String message;
//   ApiException(this.message);

//   @override
//   String toString() => 'ApiException: $message';
// }

// /// Model Classes for Type Safety

// // Model for Plot Size (each with a nested "plot_size" map in the API)
// class PlotSize {
//   final int id;
//   final String size; // e.g. "250 sqm"
//   final int allocated;
//   final int totalUnits;
//   final int reserved;

//   PlotSize({
//     required this.id,
//     required this.size,
//     required this.allocated,
//     required this.totalUnits,
//     required this.reserved,
//   });

//   factory PlotSize.fromJson(Map<String, dynamic> json) {
//     // The API returns plot_size as a nested map.
//     String extractedSize = 'N/A';
//     if (json['plot_size'] is Map<String, dynamic>) {
//       extractedSize = json['plot_size']['size']?.toString() ?? 'N/A';
//     } else if (json['plot_size'] != null) {
//       extractedSize = json['plot_size'].toString();
//     }
//     return PlotSize(
//       id: json['id'] is int ? json['id'] : 0,
//       size: extractedSize,
//       allocated: json['allocated'] ?? 0,
//       totalUnits: json['total_units'] ?? 0,
//       reserved: json['reserved'] ?? 0,
//     );
//   }
// }

// // Model for Plot Number
// class PlotNumber {
//   final int id;
//   final String number;
//   final bool isAllocated;

//   PlotNumber({
//     required this.id,
//     required this.number,
//     required this.isAllocated,
//   });

//   factory PlotNumber.fromJson(Map<String, dynamic> json) {
//     return PlotNumber(
//       id: json['id'] is int ? json['id'] : 0,
//       number: json['number']?.toString() ?? 'N/A',
//       isAllocated: json['is_allocated'] ?? false,
//     );
//   }
// }

// // Model for EstatePlot (includes lists of PlotSizes and PlotNumbers)
// class EstatePlot {
//   final int id;
//   final String name;
//   final String size;
//   final List<PlotSize> plotSizes;
//   final List<PlotNumber> plotNumbers;

//   EstatePlot({
//     required this.id,
//     required this.name,
//     required this.size,
//     required this.plotSizes,
//     required this.plotNumbers,
//   });

//   factory EstatePlot.fromJson(Map<String, dynamic> json) {
//     return EstatePlot(
//       id: json['id'] is int ? json['id'] : 0,
//       name: json['name'] ?? 'Unnamed Estate Plot',
//       size: json['size'] ?? 'N/A',
//       plotSizes: (json['plot_sizes'] as List<dynamic>? ?? [])
//           .map((e) => PlotSize.fromJson(e))
//           .toList(),
//       plotNumbers: (json['plot_numbers'] as List<dynamic>? ?? [])
//           .map((e) => PlotNumber.fromJson(e))
//           .toList(),
//     );
//   }
// }

// /// EditEstatePlotScreen – Allows editing plot sizes (with unit counts) and plot numbers.
// class EditEstatePlotScreen extends StatefulWidget {
//   final EstatePlot estatePlot;
//   final String token; // Added token property

//   const EditEstatePlotScreen({
//     super.key,
//     required this.estatePlot,
//     required this.token,
//   });

//   @override
//   State<EditEstatePlotScreen> createState() => _EditEstatePlotScreenState();
// }

// class _EditEstatePlotScreenState extends State<EditEstatePlotScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final Map<int, int> _selectedUnits = {};
//   final Set<int> _selectedSizes = {};
//   final Set<int> _selectedPlots = {};
//   String? _validationError;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Edit Estate Plot', style: TextStyle(fontWeight: FontWeight.bold)),
//         elevation: 0,
//         systemOverlayStyle: SystemUiOverlayStyle.dark,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildHeader(),
//               const SizedBox(height: 30),
//               _buildPlotSizesSection(),
//               const SizedBox(height: 25),
//               _buildPlotNumbersSection(),
//               if (_validationError != null) _buildErrorBanner(),
//               const SizedBox(height: 30),
//               _buildSubmitButton(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text('Editing ${widget.estatePlot.name}',
//             style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                   fontWeight: FontWeight.w600,
//                   color: Colors.blueGrey[800],
//                 )),
//         const SizedBox(height: 8),
//         Text('Estate Size: ${widget.estatePlot.size} sqm',
//             style: TextStyle(color: Colors.blueGrey[600], fontSize: 16)),
//       ],
//     );
//   }

//   Widget _buildPlotSizesSection() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const _SectionTitle(title: 'Plot Sizes & Units', icon: Icons.aspect_ratio),
//             const SizedBox(height: 15),
//             ...widget.estatePlot.plotSizes.map((size) => _buildSizeRow(size)).toList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSizeRow(PlotSize size) {
//     final isSelected = _selectedSizes.contains(size.id);
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         children: [
//           Checkbox(
//             value: isSelected,
//             onChanged: (v) => _toggleSizeSelection(size.id, v!),
//           ),
//           Expanded(
//             child: Text('${size.size}',
//                 style: TextStyle(
//                     fontSize: 16,
//                     color: isSelected ? Colors.blueGrey[800] : Colors.grey)),
//           ),
//           SizedBox(
//             width: 150,
//             child: TextFormField(
//               enabled: isSelected,
//               keyboardType: TextInputType.number,
//               decoration: InputDecoration(
//                 labelText: 'Units',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 contentPadding: const EdgeInsets.symmetric(horizontal: 15),
//               ),
//               validator: (value) => isSelected && (value == null || value.isEmpty)
//                   ? 'Required'
//                   : null,
//               onChanged: (v) => _selectedUnits[size.id] = int.tryParse(v) ?? 0,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildPlotNumbersSection() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const _SectionTitle(title: 'Plot Numbers', icon: Icons.numbers),
//             const SizedBox(height: 15),
//             Wrap(
//               spacing: 12,
//               runSpacing: 12,
//               children: widget.estatePlot.plotNumbers.map((plot) => _buildPlotChip(plot)).toList(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPlotChip(PlotNumber plot) {
//     final isSelected = _selectedPlots.contains(plot.id);
//     return FilterChip(
//       label: Text(plot.number),
//       selected: isSelected,
//       onSelected: (v) => setState(() {
//         if (v) {
//           _selectedPlots.add(plot.id);
//         } else {
//           _selectedPlots.remove(plot.id);
//         }
//       }),
//       selectedColor: Colors.blue[100],
//       checkmarkColor: Colors.blue[800],
//       labelStyle: TextStyle(
//         color: isSelected ? Colors.blue[800] : Colors.grey[700],
//         fontWeight: FontWeight.w500,
//       ),
//       shape: StadiumBorder(
//         side: BorderSide(
//           color: isSelected ? Colors.blue.shade800 : Colors.grey.shade300,
//         ),
//       ),
//     );
//   }

//   Widget _buildErrorBanner() {
//     return Container(
//       padding: const EdgeInsets.all(15),
//       decoration: BoxDecoration(
//         color: Colors.red[50],
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.red.shade200),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.error_outline, color: Colors.red[800]),
//           const SizedBox(width: 12),
//           Expanded(child: Text(_validationError!, style: TextStyle(color: Colors.red[800]))),
//         ],
//       ),
//     );
//   }

//   Widget _buildSubmitButton() {
//     return SizedBox(
//       width: double.infinity,
//       child: ElevatedButton.icon(
//         icon: const Icon(Icons.save_rounded),
//         label: const Text('SAVE CHANGES', style: TextStyle(letterSpacing: 1.2)),
//         style: ElevatedButton.styleFrom(
//           padding: const EdgeInsets.symmetric(vertical: 18),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           backgroundColor: Colors.blue[800],
//           foregroundColor: Colors.white,
//         ),
//         onPressed: _validateAndSubmit,
//       ),
//     );
//   }

//   void _toggleSizeSelection(int sizeId, bool selected) {
//     setState(() {
//       if (selected) {
//         _selectedSizes.add(sizeId);
//       } else {
//         _selectedSizes.remove(sizeId);
//         _selectedUnits.remove(sizeId);
//       }
//     });
//   }

//   void _validateAndSubmit() {
//     final totalUnits = _selectedUnits.values.fold(0, (sum, units) => sum + units);
//     final plotCount = _selectedPlots.length;

//     if (totalUnits != plotCount) {
//       setState(() {
//         _validationError = 'Total units ($totalUnits) must match selected plots ($plotCount)';
//       });
//       return;
//     }

//     if (_formKey.currentState!.validate()) {
//       final Map<String, dynamic> data = {
//         "plot_sizes": _selectedSizes.toList(),
//         ..._selectedUnits.map((key, value) => MapEntry("plot_units_$key", value)),
//         "plot_numbers": _selectedPlots.toList(),
//       };

//       ApiService()
//           .editEstatePlot(widget.token, widget.estatePlot.id, data)
//           .then((success) {
//         if (!mounted) return;
//         if (success) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Estate plot updated successfully')),
//           );
//           Navigator.pop(context);
//         } else {
//           setState(() {
//             _validationError = 'Failed to update estate plot. Please try again.';
//           });
//         }
//       }).catchError((error) {
//         if (!mounted) return;
//         setState(() {
//           _validationError = error.toString();
//         });
//       });
//     }
//   }
// }

// class _SectionTitle extends StatelessWidget {
//   final String title;
//   final IconData icon;

//   const _SectionTitle({required this.title, required this.icon});

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, color: Colors.blue[800], size: 24),
//         const SizedBox(width: 12),
//         Text(
//           title,
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.w600,
//             color: Colors.blueGrey[800],
//           ),
//         ),
//       ],
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:real_estate_app/core/api_service.dart';

class EditEstatePlotModal extends StatefulWidget {
  final String token;
  final String estateId;
  final Function() onUpdate;

  const EditEstatePlotModal({
    required this.token,
    required this.estateId,
    required this.onUpdate,
    Key? key,
  }) : super(key: key);

  @override
  _EditEstatePlotModalState createState() => _EditEstatePlotModalState();
}

class _EditEstatePlotModalState extends State<EditEstatePlotModal> {
  late Future<EstatePlot> _estatePlotFuture;
  List<PlotSizePlot> _plotSizes = [];
  List<PlotNumberPlot> _plotNumbers = [];
  List<int> _selectedPlotNumbers = [];
  final Map<int, int> _plotSizeUnits = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _estatePlotFuture = _fetchEstatePlot();
  }

  Future<EstatePlot> _fetchEstatePlot() async {
    try {
      final data = await ApiService().getEstatePlot(
        estateId: widget.estateId,
        token: widget.token,
      );
      
      // Debug print to check the API response structure

      // Handle case where plot_sizes or plot_numbers might be null
      final plotSizes = data['plot_sizes'] as List? ?? [];
      final plotNumbers = data['plot_numbers'] as List? ?? [];
      
      return EstatePlot.fromJson({
        'plot_sizes': plotSizes,
        'plot_numbers': plotNumbers,
      });
    } catch (e) {
      throw Exception('Failed to load estate plot: $e');
    }
  }

  void _showResultModal({required bool isSuccess, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              isSuccess ? 'Success' : 'Error',
              style: TextStyle(
                color: isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isSuccess) {
                Navigator.of(context).pop();
                widget.onUpdate();
              }
            },
            child: const Text('OK'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _updateEstatePlot() async {
    // Validate that total units match selected plot numbers
    final totalUnits = _plotSizeUnits.values.fold(0, (sum, units) => sum + units);
    if (totalUnits != _selectedPlotNumbers.length) {
      _showResultModal(
        isSuccess: false,
        message: 'Total plot size units must equal the total plot numbers selected',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare update data
      final updateData = {
        'plot_sizes': _plotSizeUnits.entries
            .map((e) => {'id': e.key, 'units': e.value})
            .toList(),
        'plot_numbers': _selectedPlotNumbers,
      };

      await ApiService().updateEstatePlot(
        estateId: widget.estateId,
        token: widget.token,
        data: updateData,
      );

      _showResultModal(
        isSuccess: true,
        message: 'Estate plot updated successfully!',
      );
    } catch (e) {
      _showResultModal(
        isSuccess: false,
        message: 'Failed to update estate plot: ${e.toString()}',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: FutureBuilder<EstatePlot>(
        future: _estatePlotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          } else if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          } else if (snapshot.hasData) {
            final estatePlot = snapshot.data!;
            _plotSizes = estatePlot.plotSizes;
            _plotNumbers = estatePlot.plotNumbers;
            _selectedPlotNumbers = estatePlot.plotNumbers
                .where((pn) => pn.isSelected)
                .map((pn) => pn.id)
                .toList();
            
            // Initialize plot size units
            for (var size in estatePlot.plotSizes) {
              _plotSizeUnits[size.id] = size.totalUnits;
            }

            return _buildContent(estatePlot);
          }
          return Container();
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load estate plot',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _estatePlotFuture = _fetchEstatePlot();
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(EstatePlot estatePlot) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Edit Estate Plot',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPlotSizesSection(),
            const SizedBox(height: 24),
            _buildPlotNumbersSection(),
            const SizedBox(height: 24),
            _buildValidationMessage(),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isLoading ? null : _updateEstatePlot,
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Update Estate Plot',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlotSizesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plot Sizes & Units',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ..._plotSizes.map((size) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _plotSizeUnits.containsKey(size.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _plotSizeUnits[size.id] = size.totalUnits;
                          } else {
                            _plotSizeUnits.remove(size.id);
                          }
                        });
                      },
                    ),
                    Text('${size.size} sqm'),
                    const Spacer(),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        initialValue: size.totalUnits.toString(),
                        keyboardType: TextInputType.number,
                        enabled: _plotSizeUnits.containsKey(size.id),
                        onChanged: (value) {
                          final units = int.tryParse(value) ?? 0;
                          setState(() {
                            _plotSizeUnits[size.id] = units;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Units',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPlotNumbersSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plot Numbers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _plotNumbers.map((plot) {
                return FilterChip(
                  label: Text(plot.number),
                  selected: _selectedPlotNumbers.contains(plot.id),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedPlotNumbers.add(plot.id);
                      } else {
                        _selectedPlotNumbers.remove(plot.id);
                      }
                    });
                  },
                  selectedColor: Colors.blue.shade100,
                  checkmarkColor: Colors.blue,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationMessage() {
    final totalUnits = _plotSizeUnits.values.fold(0, (sum, units) => sum + units);
    final selectedPlotNumbers = _selectedPlotNumbers.length;
    
    if (totalUnits != selectedPlotNumbers) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Text(
          'Total plot size units ($totalUnits) not equal to the total plot numbers selected ($selectedPlotNumbers)',
          style: const TextStyle(color: Colors.orange),
        ),
      );
    }
    return Container();
  }
}

class PlotSizePlot {
  final int id;
  final String size;
  int totalUnits;
  int allocatedUnits;
  int reservedUnits;
  bool isSelected;

  PlotSizePlot({
    required this.id,
    required this.size,
    this.totalUnits = 0,
    this.allocatedUnits = 0,
    this.reservedUnits = 0,
    this.isSelected = false,
  });

  factory PlotSizePlot.fromJson(Map<String, dynamic> json) {
    try {
      return PlotSizePlot(
        id: json['id'] ?? 0,
        size: json['plot_size'] is Map 
            ? (json['plot_size']['size'] ?? 'Unknown Size')
            : json['size']?.toString() ?? 'Unknown Size',
        totalUnits: json['total_units'] ?? 0,
        allocatedUnits: json['allocated_units'] ?? 0,
        reservedUnits: json['reserved_units'] ?? 0,
      );
    } catch (e) {

      return PlotSizePlot(
        id: 0,
        size: 'Error',
      );
    }
  }
}

class PlotNumberPlot {
  final int id;
  final String number;
  bool isAllocated;
  bool isSelected;

  PlotNumberPlot({
    required this.id,
    required this.number,
    this.isAllocated = false,
    this.isSelected = false,
  });

  factory PlotNumberPlot.fromJson(Map<String, dynamic> json) {
    try {
      return PlotNumberPlot(
        id: json['id'] ?? 0,
        number: json['number']?.toString() ?? 'Unknown',
        isAllocated: json['is_allocated'] ?? false,
      );
    } catch (e) {

      return PlotNumberPlot(
        id: 0,
        number: 'Error',
      );
    }
  }
}

class EstatePlot {
  final List<PlotSizePlot> plotSizes;
  final List<PlotNumberPlot> plotNumbers;

  EstatePlot({
    required this.plotSizes,
    required this.plotNumbers,
  });

  factory EstatePlot.fromJson(Map<String, dynamic> json) {
    try {
      final plotSizes = (json['plot_sizes'] as List?)?.map((e) {
        return PlotSizePlot.fromJson(e);
      }).toList() ?? [];

      final plotNumbers = (json['plot_numbers'] as List?)?.map((e) {
        return PlotNumberPlot.fromJson(e);
      }).toList() ?? [];

      return EstatePlot(
        plotSizes: plotSizes,
        plotNumbers: plotNumbers,
      );
    } catch (e) {

      return EstatePlot(
        plotSizes: [],
        plotNumbers: [],
      );
    }
  }
}


