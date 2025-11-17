import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/admin/models/admin_user_registration.dart';
import 'admin_layout.dart';

class RegisterClientMarketer extends StatefulWidget {
  final String token;
  const RegisterClientMarketer({required this.token, Key? key}) : super(key: key);

  @override
  _RegisterClientMarketerState createState() => _RegisterClientMarketerState();
}

class _RegisterClientMarketerState extends State<RegisterClientMarketer>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  String _selectedRole = 'admin';
  String? _selectedMarketer;
  List<Map<String, dynamic>> _marketers = [];
  bool _isLoadingMarketers = false;
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  

  // @override
  // void initState() {
  //   super.initState();

  //   _animationController = AnimationController(
  //     vsync: this,
  //     duration: Duration(milliseconds: 1000),
  //   );
  //   _fadeAnimation = CurvedAnimation(
  //     parent: _animationController,
  //     curve: Curves.easeInOut,
  //   );
  //   _slideAnimation = Tween<Offset>(
  //     begin: Offset(0, 0.1),
  //     end: Offset.zero,
  //   ).animate(
  //     CurvedAnimation(
  //       parent: _animationController,
  //       curve: Curves.easeOutQuad,
  //     ),
  //   );
  //   _animationController.forward();

  //   _nameController.addListener(() {
  //     if (_nameController.text.trim().length >= 3) {
  //       _passwordController.text = generatePassword(_nameController.text);
  //     } else {
  //       _passwordController.text = '';
  //     }
  //   });

  //   _fetchMarketers();
  // }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuad));
    _animationController.forward();

    _nameController.addListener(() {
      if (_nameController.text.trim().length >= 3) {
        _passwordController.text = generatePassword(_nameController.text);
      } else {
        _passwordController.text = '';
      }
    });

    _fetchMarketers();
  }

  Future<void> _fetchMarketers() async {
    setState(() {
      _isLoadingMarketers = true;
    });
    try {
      final fetchedMarketers = await ApiService().fetchMarketers(widget.token);
      setState(() {
        _marketers = fetchedMarketers;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load marketers: $e')));
    } finally {
      setState(() {
        _isLoadingMarketers = false;
      });
    }
  }

  String generatePassword(String name) {
    List<String> parts = name.trim().split(' ');
    String base = parts.join('_').toLowerCase();
    int randomNumber = DateTime.now().millisecondsSinceEpoch % 1000;
    return '$base$randomNumber';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now().subtract(Duration(days: 365 * 18));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: Color(0xFF6C5CE7),
            onPrimary: Colors.white,
          ),
          dialogBackgroundColor: Colors.white,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }
  

  // Future<void> _registerUser() async {
  //   if (_formKey.currentState?.validate() ?? false) {
  //     setState(() {
  //       _isSubmitting = true;
  //     });

  //     AppUser newUser = AppUser(
  //       fullName: _nameController.text.trim(),
  //       password: _passwordController.text.trim(),
  //       address: _addressController.text.trim(),
  //       phone: _phoneController.text.trim(),
  //       email: _emailController.text.trim(),
  //       dateOfBirth: _dobController.text.trim(),
  //       role: _selectedRole,
  //       marketerId: _selectedRole == 'client' ? int.tryParse(_selectedMarketer ?? '') : null,
  //     );


  //     try {
  //       await ApiService().registerAdminUser(newUser.toJson(), widget.token);
  //       showDialog(
  //         context: context,
  //         builder: (context) => Dialog(
  //           backgroundColor: Colors.transparent,
  //           child: Container(
  //             decoration: BoxDecoration(
  //               color: Colors.white,
  //               borderRadius: BorderRadius.circular(20),
  //               boxShadow: [
  //                 BoxShadow(
  //                     color: Colors.black.withOpacity(0.2),
  //                     blurRadius: 20,
  //                     offset: Offset(0, 10)),
  //               ],
  //             ),
  //             padding: EdgeInsets.all(25),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 Icon(Icons.check_circle,
  //                     color: Color(0xFF6C5CE7), size: 60),
  //                 SizedBox(height: 20),
  //                 Text('Registration Successful',
  //                     style: TextStyle(
  //                         fontSize: 22, fontWeight: FontWeight.w600)),
  //                 SizedBox(height: 15),
  //                 Text('User has been registered successfully.',
  //                     style: TextStyle(color: Colors.grey.shade600)),
  //                 SizedBox(height: 25),
  //                 ElevatedButton(
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: Color(0xFF6C5CE7),
  //                     padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
  //                     shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.circular(12)),
  //                   ),
  //                   onPressed: () => Navigator.pop(context),
  //                   child: Text('OK', style: TextStyle(fontSize: 16)),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       );
  //     } catch (e) {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(SnackBar(content: Text('Registration failed: $e')));
  //     } finally {
  //       setState(() {
  //         _isSubmitting = false;
  //       });
  //     }
  //   }
  // }

  Future<void> _registerUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      AppUser newUser = AppUser(
        fullName: _nameController.text.trim(),
        password: _passwordController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        dateOfBirth: _dobController.text.trim(),
        role: _selectedRole,
        marketerId: _selectedRole == 'client' ? int.tryParse(_selectedMarketer ?? '') : null,
      );

      try {
        await ApiService().registerAdminUser(newUser.toJson(), widget.token);
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
                      offset: Offset(0, 10)),
                ],
              ),
              padding: EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF6C5CE7), size: 60),
                  SizedBox(height: 20),
                  Text('Registration Successful',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  SizedBox(height: 15),
                  Text('User has been registered successfully.',
                      style: TextStyle(color: Colors.grey.shade600)),
                  SizedBox(height: 25),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6C5CE7),
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        );
      } catch (e) {
        // Handle API errors similar to backend responses
        String errorMessage = '';
        if (e.toString().contains("Email already Registered")) {
          errorMessage = 'This email is already registered.';
        } else if (e.toString().contains("Database integrity error occurred")) {
          errorMessage = 'A database error occurred. Please try again later.';
        } else {
          errorMessage = 'An error occurred: $e';
        }

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
                      offset: Offset(0, 10)),
                ],
              ),
              padding: EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 60),
                  SizedBox(height: 20),
                  Text('Registration Failed',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  SizedBox(height: 15),
                  Text(errorMessage, style: TextStyle(color: Colors.grey.shade600)),
                  SizedBox(height: 25),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }


  InputDecoration _inputDecoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Color(0xFF6C5CE7).withOpacity(0.7)),
      labelStyle: TextStyle(color: Colors.grey.shade600),
      floatingLabelStyle: TextStyle(color: Color(0xFF6C5CE7)),
      contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Color(0xFF6C5CE7), width: 1.5)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      readOnly: true,
      decoration: _inputDecoration(label: 'Generated Password', icon: Icons.lock).copyWith(
        suffixIcon: IconButton(
          icon: Icon(Icons.copy),
          tooltip: 'Copy Password',
          onPressed: () {
            final password = _passwordController.text.trim();
            if (password.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: password));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Password copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dobController,
      readOnly: true,
      onTap: () => _selectDate(context),
      decoration: _inputDecoration(label: 'Date of Birth', icon: Icons.cake).copyWith(
          suffixIcon: Icon(Icons.calendar_today, color: Colors.grey.shade500)),
      validator: (v) => (v == null || v.isEmpty) ? 'Please select date' : null,
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: _inputDecoration(label: 'Role', icon: Icons.assignment_ind),
      items: [
        _buildDropdownItem('Admin', Icons.admin_panel_settings),
        _buildDropdownItem('Client', Icons.person_outline),
        _buildDropdownItem('Marketer', Icons.people_alt_outlined),
      ],
      onChanged: (v) => setState(() => _selectedRole = v!),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(String text, IconData icon) {
    return DropdownMenuItem(
      value: text.toLowerCase(),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF6C5CE7), size: 20),
          SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildMarketerDropdown() {
    if (_isLoadingMarketers) {
      return Center(child: CircularProgressIndicator());
    }

    if (_marketers.isEmpty) {
      return Text('No marketers available');
    }

    return DropdownButtonFormField<String>(
      value: _selectedMarketer,
      decoration: _inputDecoration(label: 'Select Marketer', icon: Icons.groups),
      items: _marketers
          .map((m) => DropdownMenuItem(
                value: m['id'].toString(),
                child: Text(m['full_name'] ?? '', style: TextStyle(fontSize: 15)),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedMarketer = v),
      validator: (v) => v == null ? 'Please select marketer' : null,
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboard, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: _inputDecoration(label: label, icon: icon),
      validator: validator,
    );
  }

  Widget _buildSubmitButton() {
    return Material(
      borderRadius: BorderRadius.circular(15),
      elevation: 5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFF8477FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _registerUser,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: 18, horizontal: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.how_to_reg, color: Colors.white),
              SizedBox(width: 12),
              Text(
                _isSubmitting ? 'Registering...' : 'Register User',
                style: TextStyle(fontSize: 16, letterSpacing: 0.5, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF8F9FF), Color(0xFFF3F4FF)]),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                      color: Colors.blueGrey.withOpacity(0.1),
                      blurRadius: 30,
                      offset: Offset(0, 15)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text('Admin User Registration',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D3436),
                            letterSpacing: 0.5)),
                    SizedBox(height: 30),
                    _buildInputField(_nameController, 'Full Name', Icons.person,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Please enter full name' : null),
                    SizedBox(height: 20),
                    _buildPasswordField(),
                    SizedBox(height: 20),
                    _buildInputField(_addressController, 'Residential Address', Icons.home),
                    SizedBox(height: 20),
                    _buildInputField(_phoneController, 'Phone Number', Icons.phone,
                        keyboard: TextInputType.phone),
                    SizedBox(height: 20),
                    _buildInputField(_emailController, 'Email Address', Icons.email,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) => v == null ||
                                !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)
                            ? 'Invalid email'
                            : null),
                    SizedBox(height: 20),
                    _buildDateField(),
                    SizedBox(height: 20),
                    _buildRoleDropdown(),
                    SizedBox(height: 20),
                    if (_selectedRole == 'client') _buildMarketerDropdown(),
                    SizedBox(height: 30),
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

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      pageTitle: 'User Registration',
      token: widget.token,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildFormContent(),
      ),
    );
  }
}
