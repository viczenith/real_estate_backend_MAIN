import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'admin_layout.dart';

class MarketerProfilePage extends StatefulWidget {
  final int marketerId;
  final String token;

  const MarketerProfilePage({Key? key, required this.marketerId, required this.token})
      : super(key: key);

  @override
  _MarketerProfilePageState createState() => _MarketerProfilePageState();
}

class _MarketerProfilePageState extends State<MarketerProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  // Original and current field values
  Map<String, dynamic> _originalData = {};
  Map<String, dynamic> _currentData = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMarketerData();
  }

  Future<void> _loadMarketerData() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getMarketerDetail(
        marketerId: widget.marketerId,
        token: widget.token,
      );
      setState(() {
        _originalData = Map<String, dynamic>.from(data);
        _currentData = Map<String, dynamic>.from(data);
      });
    } catch (e) {
      _showModal('Error', 'Failed to load marketer data:\n${e.toString()}');
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
      await ApiService().updateMarketerProfile(
        marketerId: widget.marketerId,
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
      await _loadMarketerData();
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String dynamicPageTitle =
        _currentData['full_name']?.isNotEmpty == true ? '${_currentData['full_name']} Profile' : 'Marketer Profile';

    return AdminLayout(
      pageTitle: dynamicPageTitle,
      token: widget.token,
      child: Scaffold(
        appBar: AppBar(
          title: Text(dynamicPageTitle),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Edit Profile'),
            ],
            indicatorColor: Colors.black,
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.black,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProfileHeader(
            name: _currentData['full_name'] ?? '',
            job: _currentData['job'] ?? '',
            imageUrl: _currentData['profile_image'],
          ),
          const SizedBox(height: 24),
          _sectionTitle('About'),
          Text(_currentData['about'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          _sectionTitle('Profile Details'),
          _DetailRow(label: 'Full Name', value: _currentData['full_name'] ?? '-'),
          _DetailRow(label: 'Company', value: _currentData['company'] ?? '-'),
          _DetailRow(label: 'Job', value: _currentData['job'] ?? '-'),
          _DetailRow(label: 'Country', value: _currentData['country'] ?? '-'),
          _DetailRow(label: 'Address', value: _currentData['address'] ?? '-'),
          _DetailRow(label: 'Phone', value: _currentData['phone'] ?? '-'),
          _DetailRow(label: 'Email', value: _currentData['email'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildEditTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildProfileImageField(),
            const SizedBox(height: 24),
            _buildTextField('Full Name', 'full_name'),
            _buildTextField('About', 'about', maxLines: 3),
            _buildTextField('Company', 'company'),
            _buildTextField('Job', 'job'),
            _buildTextField('Country', 'country'),
            _buildTextField('Address', 'address'),
            _buildTextField('Phone', 'phone', keyboardType: TextInputType.phone),
            _buildTextField('Email', 'email', keyboardType: TextInputType.emailAddress, validator: _emailValidator),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  : const Text('Save Changes'),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
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
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[200],
            backgroundImage: _profileImage != null
                ? FileImage(_profileImage!)
                : (_currentData['profile_image'] != null
                    ? CachedNetworkImageProvider(_currentData['profile_image'])
                    : const AssetImage('assets/avater.webp')) as ImageProvider,
            child: (_profileImage == null && _currentData['profile_image'] == null)
                ? const Icon(Icons.person, size: 60, color: Colors.grey)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: _pickImage,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  String? _emailValidator(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String job;
  final String? imageUrl;

  const _ProfileHeader({required this.name, required this.job, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.grey[200],
          backgroundImage: imageUrl != null
              ? CachedNetworkImageProvider(imageUrl!)
              : const AssetImage('assets/avater.webp') as ImageProvider,
          child: imageUrl == null
              ? const Icon(Icons.person, size: 50, color: Colors.grey)
              : null,
        ),
        const SizedBox(height: 16),
        Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(job, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text(value)),
        ],
      ),
    );
  }
}
