import 'package:flutter/material.dart';
import 'admin_layout.dart';

class SendNotification extends StatefulWidget {
  final String token;
  const SendNotification({required this.token, super.key});

  @override
  _SendNotificationState createState() => _SendNotificationState();
}

class _SendNotificationState extends State<SendNotification>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Form Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String? _selectedType = 'General';
  bool _isSubmitting = false;

  final List<String> _notificationTypes = [
    'General',
    'Urgent',
    'Update',
    'Maintenance'
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuad,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showResultDialog(
          success: true,
          message: 'Notification sent successfully to 150 recipients',
        );
        _formKey.currentState!.reset();
      }
    }
  }

  void _showResultDialog({required bool success, required String message}) {
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
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                success ? 'Success!' : 'Error!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: success ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: success ? Colors.green : Colors.red,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.deepPurple.shade600),
      labelStyle: TextStyle(color: Colors.grey.shade600),
      floatingLabelStyle: TextStyle(color: Colors.deepPurple.shade600),
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
        borderSide: BorderSide(
            color: Colors.deepPurple.shade600,
            width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.shade50,
                    Colors.blue.shade50,
                  ],
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
                    Text(
                      'Broadcast Message',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.deepPurple.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Notification Type Dropdown
                    DropdownButtonFormField<String>(
                      decoration: _inputDecoration(
                          'Announcement Type', Icons.category),
                      value: _selectedType,
                      items: _notificationTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedType = value),
                      validator: (value) =>
                          value == null ? 'Please select a type' : null,
                    ),
                    const SizedBox(height: 20),

                    // Title Field
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration('Title', Icons.title),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a title' : null,
                    ),
                    const SizedBox(height: 20),

                    // Message Field
                    TextFormField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration:
                          _inputDecoration('Message', Icons.message_rounded),
                      validator: (value) =>
                          value!.isEmpty ? 'Please enter a message' : null,
                    ),
                    const SizedBox(height: 30),

                    // Submit Button
                    Material(
                      borderRadius: BorderRadius.circular(30),
                      elevation: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade600,
                              Colors.blue.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _isSubmitting
                                    ? 'Sending...'
                                    : 'Send Announcement',
                                style: const TextStyle(
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
      pageTitle: 'Send Notification',
      token: widget.token,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Breadcrumb
            Row(
              children: [
                Text('Home / ', style: TextStyle(color: Colors.grey.shade600)),
                Text('Send Notifications',
                    style: TextStyle(
                      color: Colors.deepPurple.shade600,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              'Send Notifications',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.deepPurple.shade800,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            // Form Content
            Expanded(child: _buildFormContent()),
          ],
        ),
      ),
    );
  }
}