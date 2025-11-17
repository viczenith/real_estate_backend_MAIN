import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'admin_layout.dart';

class ClientProfilePage extends StatefulWidget {
  final int clientId;
  final String token;

  const ClientProfilePage({Key? key, required this.clientId, required this.token})
      : super(key: key);

  @override
  _ClientProfilePageState createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic> _originalData = {};
  Map<String, dynamic> _currentData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadClientData();
  }

  Future<void> _loadClientData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getClientDetail(
        clientId: widget.clientId,
        token: widget.token,
      );
      setState(() {
        _originalData = Map<String, dynamic>.from(data);
        _currentData = Map<String, dynamic>.from(data);
        // Reset the local image file when loading new data
        _profileImage = null;
      });
    } catch (e) {
      _showModal('Error', 'Failed to load client data:\n${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } on PlatformException catch (e) {
      _showModal('Error', 'Image pick failed:\n${e.message}');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    Map<String, String> updatedFields = {};
    _currentData.forEach((key, value) {
      if (key == 'profile_image') return;
      if (_originalData[key] != value) {
        updatedFields[key] = value ?? '';
      }
    });

    setState(() => _isLoading = true);

    try {
      await ApiService().updateClientProfile(
        clientId: widget.clientId,
        token: widget.token,
        fullName: updatedFields['full_name'] ?? _originalData['full_name'],
        about: updatedFields['about'] ?? _originalData['about'],
        company: updatedFields['company'] ?? _originalData['company'],
        job: updatedFields['job'] ?? _originalData['job'],
        country: updatedFields['country'] ?? _originalData['country'],
        address: updatedFields['address'] ?? _originalData['address'],
        phone: updatedFields['phone'] ?? _originalData['phone'],
        email: updatedFields['email'] ?? _originalData['email'],
        profileImage: _profileImage,
      );
      _showModal('Success', 'Profile updated successfully.');
      await _loadClientData(); // This will refresh the data including the new image
      _tabController.animateTo(0);
    } catch (e) {
      _showModal('Update Failed', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showModal(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF)),
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFF6C63FF))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String dynamicPageTitle = _currentData['full_name']?.isNotEmpty == true
        ? '${_currentData['full_name']} Profile'
        : 'Client Profile';

    return AdminLayout(
      pageTitle: dynamicPageTitle,
      token: widget.token,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            dynamicPageTitle,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF6C63FF),
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.person_outline), text: 'Overview'),
              Tab(icon: Icon(Icons.edit_outlined), text: 'Edit Profile'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildEditTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeader(
            name: _currentData['full_name'] ?? '',
            job: _currentData['job'] ?? '',
            imageUrl: _currentData['profile_image'],
          ),
          const SizedBox(height: 30),
          _sectionTitle('About'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _currentData['about'] ?? '',
              style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 30),
          _sectionTitle('Profile Details'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _DetailRow(label: 'Full Name', value: _currentData['full_name'] ?? '-', icon: Icons.person),
                const Divider(height: 20, color: Colors.grey),
                _DetailRow(label: 'Company', value: _currentData['company'] ?? '-', icon: Icons.business),
                const Divider(height: 20, color: Colors.grey),
                _DetailRow(label: 'Job', value: _currentData['job'] ?? '-', icon: Icons.work),
                const Divider(height: 20, color: Colors.grey),
                _DetailRow(label: 'Country', value: _currentData['country'] ?? '-', icon: Icons.flag),
                const Divider(height: 20, color: Colors.grey),
                _DetailRow(label: 'Address', value: _currentData['address'] ?? '-', icon: Icons.home),
                const Divider(height: 20, color: Colors.grey),
                _DetailRow(label: 'Phone', value: _currentData['phone'] ?? '-', icon: Icons.phone),
                const Divider(height: 20, color: Colors.grey),
                _DetailRow(label: 'Email', value: _currentData['email'] ?? '-', icon: Icons.email),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildProfileImageField(),
            const SizedBox(height: 30),
            _buildTextField('Full Name', 'full_name'),
            _buildTextField('About', 'about', maxLines: 3),
            _buildTextField('Company', 'company'),
            _buildTextField('Job', 'job'),
            _buildTextField('Country', 'country'),
            _buildTextField('Address', 'address'),
            _buildTextField('Phone', 'phone', keyboardType: TextInputType.phone),
            _buildTextField('Email', 'email', keyboardType: TextInputType.emailAddress, validator: _emailValidator),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String field, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        initialValue: _currentData[field] ?? '',
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6C63FF)),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(color: Colors.black87),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        onSaved: (val) => _currentData[field] = val,
      ),
    );
  }

  Widget _buildProfileImageField() {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6C63FF),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: _profileImage != null
                  ? Image.file(_profileImage!, fit: BoxFit.cover)
                  : (_currentData['profile_image'] != null
                      ? CachedNetworkImage(
                          imageUrl: _currentData['profile_image'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.person, size: 50, color: Colors.grey),
                        )
                      : const Icon(Icons.person, size: 50, color: Colors.grey)),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF6C63FF),
        ),
      ),
    );
  }

  String? _emailValidator(String? email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$');
    if (email != null && email.isNotEmpty && !regex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String job;
  final String? imageUrl;

  const _ProfileHeader({
    required this.name,
    required this.job,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF6C63FF),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.person, size: 40, color: Colors.grey),
                    )
                  : const Icon(Icons.person, size: 40, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  job,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
