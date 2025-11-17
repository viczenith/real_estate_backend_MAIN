import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/models/update_allocation_model.dart';

class UpdateAllocationScreen extends StatefulWidget {
  final AllocationUpdate allocation;
  final List<Client> clients;
  final List<Estate> estates;
  final List<PlotSizeUnit> plotSizeUnits;
  final List<PlotNumber> plotNumbers;
  final String token;

  const UpdateAllocationScreen({
    required this.allocation,
    required this.clients,
    required this.estates,
    required this.plotSizeUnits,
    required this.plotNumbers,
    required this.token,
    super.key,
  });

  @override
  _UpdateAllocationScreenState createState() => _UpdateAllocationScreenState();
}

class _UpdateAllocationScreenState extends State<UpdateAllocationScreen> {
  late TextEditingController _clientController;
  late TextEditingController _estateController;
  String? _selectedPlotSizeUnitId;
  String? _selectedPlotNumberId;
  String? _selectedPaymentType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _clientController = TextEditingController(
      text: widget.allocation.client.fullName,
    );
    _estateController = TextEditingController(
      text: widget.allocation.estate.name,
    );

    // Initialize selections with validated IDs
    _initializeSelections();
  }

  void _initializeSelections() {
    // Plot Size Unit
    final currentUnit = widget.plotSizeUnits.firstWhere(
      (u) => u.id == widget.allocation.plotSizeUnit.id,
      orElse: () => widget.plotSizeUnits.first,
    );
    _selectedPlotSizeUnitId = currentUnit.id;

    // Payment Type
    _selectedPaymentType = widget.allocation.paymentType;

    // Plot Number
    if (widget.allocation.plotNumber != null) {
      final currentPlot = widget.plotNumbers.firstWhere(
        (p) => p.id == widget.allocation.plotNumber!.id,
        orElse: () => PlotNumber(
          id: widget.allocation.plotNumber!.id,
          number: 'N/A',
          isAllocated: true,
        ),
      );
      _selectedPlotNumberId = currentPlot.id;
    }
  }

  List<DropdownMenuItem<String>> _buildPlotNumberItems() {
    final items = <DropdownMenuItem<String>>[];
    final currentPlot = widget.allocation.plotNumber;
    final currentId = currentPlot?.id;
    final usedIds = <String>{};

    // Add current plot if not in main list
    if (currentId != null && 
        !widget.plotNumbers.any((p) => p.id == currentId)) {
      items.add(DropdownMenuItem(
        value: currentId,
        child: Text('${currentPlot!.number} (current)'),
      ));
      usedIds.add(currentId);
    }

    // Add available plots
    for (final p in widget.plotNumbers) {
      if (usedIds.contains(p.id)) continue;
      
      final isAllocated = p.isAllocated && p.id != currentId;
      items.add(DropdownMenuItem(
        value: p.id,
        enabled: !isAllocated,
        child: Text(
          isAllocated ? '${p.number} (taken)' : p.number,
          style: TextStyle(
            color: isAllocated ? Colors.grey : null,
            fontStyle: isAllocated ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ));
      usedIds.add(p.id);
    }

    return items;
  }
  Future<void> _updateAllocation() async {
    if (_selectedPlotSizeUnitId == null || 
        _selectedPaymentType == null ||
        (_selectedPaymentType == 'full' && _selectedPlotNumberId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Convert to integers and validate
    final plotSizeUnitId = int.tryParse(_selectedPlotSizeUnitId!);
    final plotNumberId = _selectedPlotNumberId != null 
        ? int.tryParse(_selectedPlotNumberId!) 
        : null;

    if (plotSizeUnitId == null || 
        (_selectedPaymentType == 'full' && plotNumberId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid plot selection')),
      );
      return;
    }

    final data = {
      'plot_size_unit': plotSizeUnitId,
      'payment_type': _selectedPaymentType!,
      if (_selectedPaymentType == 'full') 'plot_number': plotNumberId,
    };

    try {
      await ApiService().updateAllocatedPlotForEstate(
        widget.allocation.id,
        data,
        widget.token,
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final plotItems = _buildPlotNumberItems();
    final safePlotValue = plotItems.any((i) => i.value == _selectedPlotNumberId)
        ? _selectedPlotNumberId
        : null;

    return AlertDialog(
      title: const Text('Update Allocation'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _clientController,
              decoration: const InputDecoration(labelText: 'Client'),
              enabled: false,
            ),
            const Gap(16),
            TextField(
              controller: _estateController,
              decoration: const InputDecoration(labelText: 'Estate'),
              enabled: false,
            ),
            const Gap(16),
            DropdownButtonFormField<String>(
              value: _selectedPlotSizeUnitId,
              decoration: const InputDecoration(labelText: 'Plot Size'),
              items: widget.plotSizeUnits.map((u) => DropdownMenuItem(
                value: u.id,
                child: Text(u.plotSize.size),
              )).toList(),
              onChanged: (v) => setState(() => _selectedPlotSizeUnitId = v),
            ),
            const Gap(16),
            DropdownButtonFormField<String>(
              value: _selectedPaymentType,
              decoration: const InputDecoration(labelText: 'Payment Type'),
              items: const [
                DropdownMenuItem(value: 'full', child: Text('Full Payment')),
                DropdownMenuItem(value: 'part', child: Text('Part Payment')),
              ],
              onChanged: (v) => setState(() {
                _selectedPaymentType = v;
                if (v == 'part') _selectedPlotNumberId = null;
              }),
            ),
            if (_selectedPaymentType == 'full') ...[
              const Gap(16),
              DropdownButtonFormField<String>(
                value: safePlotValue,
                decoration: const InputDecoration(labelText: 'Plot Number'),
                items: plotItems,
                onChanged: (v) => setState(() => _selectedPlotNumberId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateAllocation,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _clientController.dispose();
    _estateController.dispose();
    super.dispose();
  }
}


