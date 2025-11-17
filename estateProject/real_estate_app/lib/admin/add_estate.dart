import 'package:flutter/material.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'admin_layout.dart';

class AddEstate extends StatefulWidget {
  final String token;
  const AddEstate({required this.token, super.key});

  @override
  _AddEstateState createState() => _AddEstateState();
}

class _AddEstateState extends State<AddEstate> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _estateNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _estateSizeController = TextEditingController();

  String? _selectedTitleDeed;
  final List<String> _titleDeedOptions = ['FCDA RofO', 'FCDA CofO', 'AMAC'];

  String _responseMessage = "";
  bool _responseSuccess = false;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuad,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _estateNameController.dispose();
    _locationController.dispose();
    _estateSizeController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF6C5CE7).withOpacity(0.7)),
      labelStyle: TextStyle(color: Colors.grey.shade600),
      floatingLabelStyle: const TextStyle(color: Color(0xFF6C5CE7)),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: _inputDecoration(label: label, icon: icon),
      validator: validator,
    );
  }

  Widget _buildTitleDeedDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedTitleDeed,
      decoration: _inputDecoration(label: 'Estate Title Deed', icon: Icons.description),
      items: [
        const DropdownMenuItem(
          value: '',
          child: Text('Choose Estate Title', style: TextStyle(color: Colors.grey)),
        ),
        ..._titleDeedOptions.map(
          (option) => DropdownMenuItem(
            value: option,
            child: Text(option, style: const TextStyle(fontSize: 15)),
          ),
        )
      ],
      onChanged: (v) => setState(() => _selectedTitleDeed = v),
      validator: (v) => (v == null || v.isEmpty) ? 'Please select an estate title' : null,
    );
  }

  Future<void> _addEstate() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true); // Start loading
      final result = await ApiService().addEstate(
        token: widget.token,
        estateName: _estateNameController.text,
        location: _locationController.text,
        estateSize: _estateSizeController.text,
        titleDeed: _selectedTitleDeed ?? '',
      );

      setState(() {
        _isLoading = false; // Stop loading
        _responseMessage = result['message'];
        _responseSuccess = result['success'];
      });

      if (_responseSuccess) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF6C5CE7), size: 60),
                  const SizedBox(height: 20),
                  const Text(
                    'Estate Added Successfully',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    result['message'],
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8F9FF), Color(0xFFF3F4FF)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueGrey.withOpacity(0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'Add Estate',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D3436),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildInputField(
                      _estateNameController,
                      'Estate Name',
                      Icons.home,
                      validator: (v) => v == null || v.isEmpty ? 'Please enter estate name' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      _locationController,
                      'Location',
                      Icons.location_on,
                      validator: (v) => v == null || v.isEmpty ? 'Please enter location' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      _estateSizeController,
                      'Estate Size',
                      Icons.square_foot,
                      // keyboard: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'Please enter estate size' : null,
                    ),
                    const SizedBox(height: 20),
                    _buildTitleDeedDropdown(),
                    const SizedBox(height: 20),
                    if (_responseMessage.isNotEmpty)
                      Text(
                        _responseMessage,
                        style: TextStyle(
                          color: _responseSuccess ? Colors.green : Colors.red,
                          fontSize: 16,
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Material(
      borderRadius: BorderRadius.circular(15),
      elevation: 5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF8477FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _addEstate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'Add Estate',
                      style: TextStyle(fontSize: 16, letterSpacing: 0.5, color: Colors.white),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'Add Estate',
      token: widget.token,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(child: _buildFormContent()),
          ],
        ),
      ),
    );
  }
}



