import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:real_estate_app/client/client_plot_details.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/shared/app_layout.dart';
import 'package:real_estate_app/client/client_bottom_nav.dart';
import 'package:real_estate_app/shared/app_side.dart';
import 'package:url_launcher/url_launcher.dart';

class ClientProfile extends StatefulWidget {
  final String token;

  const ClientProfile({Key? key, required this.token}) : super(key: key);

  @override
  _ClientProfileState createState() => _ClientProfileState();
}

class _ClientProfileState extends State<ClientProfile>
    with TickerProviderStateMixin {
  String? _headerImageUrl;
  String? _baseUrl;
  late final AnimationController _glowController;
  final Map<int, NumberFormat> _currencyFormatCache = {};
  // bool _aboutExpanded = false;
  bool _currentVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;


  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(',', '')) ?? 0.0;
    }
    try {
      return double.parse(v.toString());
    } catch (_) {
      return 0.0;
    }
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) {
      final s = v.replaceAll(',', '').trim();
      return int.tryParse(s) ?? (double.tryParse(s)?.toInt() ?? 0);
    }
    try {
      return int.parse(v.toString());
    } catch (_) {
      // fallback for unexpected types
      try {
        return (double.parse(v.toString())).toInt();
      } catch (_) {
        return 0;
      }
    }
  }

  String formatCurrency(dynamic valueOrDouble, {int? decimalDigits, bool forceSignForPositive = false, String locale = 'en_NG'}) {
    final double value = valueOrDouble is double ? valueOrDouble : _toDouble(valueOrDouble);

    if (value.isNaN || !value.isFinite) return '\u20A6' '0.00';
    final digits = decimalDigits ?? (value.abs() >= 1000 ? 0 : 2);

    final fmt = _currencyFormatCache.putIfAbsent(digits, () {
      return NumberFormat.currency(locale: locale, symbol: '\u20A6', decimalDigits: digits);
    });

    final formatted = fmt.format(value);
    return (forceSignForPositive && value > 0) ? '+$formatted' : formatted;
  }

  String formatPercent(dynamic valueOrDouble, {int digits = 2, bool forceSignForPositive = false}) {
    final double value = valueOrDouble is double ? valueOrDouble : _toDouble(valueOrDouble);
    if (value.isNaN || !value.isFinite) return '0.00%';

    final s = value.toStringAsFixed(digits);
    return (forceSignForPositive && value > 0) ? '+$s%' : '$s%';
  }

  late TabController _tabController;

  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<dynamic>> _propertiesFuture;
  // late Future<List<dynamic>> _appreciationFuture;
  late Future<dynamic> _appreciationFuture;


  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    
    _tabController = TabController(length: 5, vsync: this);

    // Glow controller
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadData();
  }

  void _loadData() {
    // Load profile data and extract header image
    _profileFuture =
        ApiService().getClientDetailByToken(token: widget.token).then((data) {
      final maybeHeader = (data['header_image'] ?? data['profile_image']);
      if (maybeHeader is String && maybeHeader.isNotEmpty) {
        setState(() {
          _headerImageUrl = maybeHeader;
        });
      }
      return data;
    });

    // Load properties and appreciation data (only once)
    _propertiesFuture = ApiService().getClientProperties(token: widget.token);
    _appreciationFuture = ApiService().getValueAppreciation(token: widget.token);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _tabController.dispose();

    _fullNameController.dispose();
    _aboutController.dispose();
    _companyController.dispose();
    _jobController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updatedProfile = await ApiService().updateClientProfileByToken(
          token: widget.token,
          fullName: _fullNameController.text,
          about: _aboutController.text,
          company: _companyController.text,
          job: _jobController.text,
          country: _countryController.text,
          address: _addressController.text,
          phone: _phoneController.text,
          email: _emailController.text,
          profileImage: _imageFile,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!',
                style: GoogleFonts.sora(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _profileFuture = Future.value(updatedProfile);
          _isEditing = false;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e',
                style: GoogleFonts.sora(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (_passwordFormKey.currentState!.validate()) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Passwords do not match',
                style: GoogleFonts.sora(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        await ApiService().changePasswordByToken(
          token: widget.token,
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password changed successfully!',
                style: GoogleFonts.sora(color: Colors.white)),
            backgroundColor: Colors.green,
          ),
        );

        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing password: $e',
                style: GoogleFonts.sora(color: Colors.white)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      pageTitle: 'Profile',
      token: widget.token,
      side: AppSide.client,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.light,
        ),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          bottomNavigationBar: ClientBottomNav(
            currentIndex: 1,
            token: widget.token,
            chatBadge: 1,
          ),
          body: NestedScrollView(
            floatHeaderSlivers: true,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              final double topPadding = MediaQuery.of(context).padding.top;
              final double expandedHeight = 280.0 + topPadding;

              return [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent, // ✅ prevent white tint
                  shadowColor: Colors.transparent, // ✅ no shadow glow
                  elevation: 0,
                  pinned: true,
                  stretch: true,
                  expandedHeight: expandedHeight,
                  automaticallyImplyLeading: false,
                  centerTitle: false,
                  systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: Colors.transparent,
                  ),
                  toolbarHeight: kToolbarHeight + topPadding,
                  collapsedHeight: kToolbarHeight + topPadding,
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      final double maxHeight = constraints.maxHeight;
                      final double t = ((maxHeight - (kToolbarHeight + topPadding)) /
                              (expandedHeight - (kToolbarHeight + topPadding)))
                          .clamp(0.0, 1.0);

                      const double avatarMax = 110.0;
                      const double avatarMin = 40.0;
                      final double avatarSize =
                          avatarMin + (avatarMax - avatarMin) * t;

                      final double screenWidth =
                          MediaQuery.of(context).size.width;
                      final double avatarCenterLeftExpanded =
                          (screenWidth / 2) - (avatarSize / 2);
                      final double avatarLeftCollapsed = 12.0;
                      final double avatarLeft = avatarLeftCollapsed +
                          (avatarCenterLeftExpanded - avatarLeftCollapsed) * t;

                      final double avatarTopExpanded =
                          expandedHeight - avatarSize / 2 - 16;
                      final double avatarTopCollapsed =
                          MediaQuery.of(context).padding.top +
                              (kToolbarHeight - avatarMin) / 2;
                      final double avatarTop = avatarTopCollapsed +
                          (avatarTopExpanded - avatarTopCollapsed) * t;

                      final double bigTitleOpacity = t;
                      final double smallTitleOpacity = 1.0 - t;
                      final double smallTitleLeftCollapsed =
                          avatarLeftCollapsed + avatarMin + 12.0;
                      final double smallTitleLeftExpanded = 20.0;
                      final double smallTitleLeft =
                          smallTitleLeftCollapsed +
                              (smallTitleLeftExpanded - smallTitleLeftCollapsed) *
                                  t;

                      final Widget backgroundImageWidget =
                          (_headerImageUrl != null &&
                                  _headerImageUrl!.isNotEmpty)
                              ? Image.network(
                                  _headerImageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  loadingBuilder: (c, child, progress) {
                                    if (progress == null) return child;
                                    return Container(color: Colors.grey[300]);
                                  },
                                  errorBuilder: (c, e, s) => Image.asset(
                                    'assets/avater.webp',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  'assets/avater.webp',
                                  fit: BoxFit.cover,
                                );

                      final double glowScale =
                          0.85 + (_glowController.value) * (1.35 - 0.85);
                      final double glowFactor = glowScale * (0.7 + 0.3 * t);

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // ✅ Background image fills without shifting (no white gap)
                          Positioned.fill(child: backgroundImageWidget),

                          // ✅ Gradient overlay (keeps readability)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.36),
                                    Colors.black.withOpacity(0.08),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),

                          // Large expanded title
                          Positioned(
                            left: 20,
                            bottom: 20,
                            child: Opacity(
                              opacity: bigTitleOpacity,
                              child: Text(
                                'Profile',
                                style: GoogleFonts.sora(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 6.0,
                                      color: Colors.black.withOpacity(0.45),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Small collapsed title
                          Positioned(
                            left: smallTitleLeft,
                            top: MediaQuery.of(context).padding.top + 12,
                            child: Opacity(
                              opacity: smallTitleOpacity,
                              child: Text(
                                'Profile',
                                style: GoogleFonts.sora(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          // Avatar (shrinks / slides / glows)
                          Positioned(
                            left: avatarLeft,
                            top: avatarTop,
                            child: Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4154F1)
                                        .withOpacity(0.23 * glowFactor),
                                    blurRadius: 12.0 * glowFactor,
                                    spreadRadius: 1.5 * (glowFactor - 0.9),
                                    offset: Offset(0, 6 * (1.0 - t) + 2),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.14 * t),
                                    blurRadius: 8.0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.95),
                                  width: 3.0,
                                ),
                              ),
                              child: ClipOval(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {},
                                    child: Hero(
                                      tag: 'profile-image',
                                      child: (_headerImageUrl != null &&
                                              _headerImageUrl!.isNotEmpty)
                                          ? Image.network(
                                              _headerImageUrl!,
                                              fit: BoxFit.cover,
                                              width: avatarSize,
                                              height: avatarSize,
                                              loadingBuilder: (c, child, progress) {
                                                if (progress == null) return child;
                                                return Container(
                                                    color: Colors.grey[300]);
                                              },
                                              errorBuilder: (c, e, s) =>
                                                  Image.asset(
                                                'assets/avater.webp',
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Image.asset(
                                              'assets/avater.webp',
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: const Color(0xFF4154F1),
                      indicatorWeight: 3.0,
                      labelStyle: GoogleFonts.sora(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.0,
                      ),
                      unselectedLabelStyle: GoogleFonts.sora(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.0,
                      ),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Properties'),
                        Tab(text: 'Value Appreciation'),
                        Tab(text: 'Edit Profile'),
                        Tab(text: 'Password'),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPropertiesTab(),
                _buildAppreciationTab(),
                _buildEditProfileTab(),
                _buildPasswordTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoader();
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final profile = snapshot.data!;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildProfileCard(profile),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildProfileDetails(profile),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _buildContactInfoCard(profile),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'paid complete':
      case 'fully paid':
        return Colors.green;
      case 'part payment':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPropertiesTab() {
    return FutureBuilder<List<dynamic>>(
      future: _propertiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoader();
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final properties = snapshot.data ?? <dynamic>[];

        if (properties.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.house_outlined, size: 96, color: Colors.grey[300]),
                const SizedBox(height: 20),
                Text('No Properties Found',
                    style: GoogleFonts.sora(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text("We haven't uploaded you Purchased property yet",
                    style: GoogleFonts.sora(color: Colors.grey)),
              ],
            ),
          );
        }

        // Animated staggered list using TweenAnimationBuilder for each item
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: properties.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final property = properties[index] as Map<String, dynamic>;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 350 + (index * 70)),
              builder: (context, value, child) {
                // slide from bottom + fade
                final offset = (1 - value) * 12;
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, offset),
                    child: child,
                  ),
                );
              },
              child: _buildPropertyCard(property, index),
            );
          },
        );
      },
    );
  }

  // PLOT DETAILS HELPERS
  int? _extractEstateId(Map<String, dynamic> p) {
    if (p == null) return null;

    // Common shape: transaction.allocation.estate.id
    try {
      final allocation = p['allocation'] ?? p['allocation'] ?? p['allocation_id'];
      if (allocation is Map) {
        final estate = allocation['estate'] ?? allocation['estate_id'] ?? allocation['estate_pk'];
        if (estate is Map) {
          final id = estate['id'] ?? estate['pk'];
          if (id is int) return id;
          if (id is String) return int.tryParse(id);
        }
        // sometimes allocation contains estate id directly
        final estateIdDirect = allocation['estate_id'] ?? allocation['estate'];
        if (estateIdDirect is int) return estateIdDirect;
        if (estateIdDirect is String) return int.tryParse(estateIdDirect);
      }
    } catch (_) {}

    // Fallback: top-level keys
    final cand = p['estate_id'] ?? p['estate'] ?? p['estateId'] ?? p['id'] ?? p['pk'];
    if (cand is int) return cand;
    if (cand is String) return int.tryParse(cand);
    return null;
  }
  
  // PLOT DETAILS HELPERS
  int? _extractPlotSizeId(Map<String, dynamic> p) {
    if (p == null) return null;

    // Common shape: transaction.allocation.plot_size.id or allocation.plot_size
    try {
      final allocation = p['allocation'] ?? p['allocation'] ?? p['allocation_id'];
      if (allocation is Map) {
        final ps = allocation['plot_size'] ?? allocation['plotSize'] ?? allocation['plot_size_id'];
        if (ps is Map) {
          final id = ps['id'] ?? ps['pk'];
          if (id is int) return id;
          if (id is String) return int.tryParse(id);
        }
        if (ps is int) return ps;
        if (ps is String) return int.tryParse(ps);
      }
    } catch (_) {}

    // fallbacks
    final cand = p['plot_size_id'] ?? p['plot_size'] ?? p['plotSize'] ?? p['plotSizeId'];
    if (cand is int) return cand;
    if (cand is String) return int.tryParse(cand);
    return null;
  }


  Widget _buildPropertyCard(Map<String, dynamic> property, int index) {
    final String estateName =
        (property['estate_name'] ?? 'Unknown Estate').toString();
    final String plotSize = (property['plot_size'] ?? 'N/A').toString();
    final String plotNumber =
        (property['plot_number'] ?? 'Reserved').toString();
    final double purchasePrice = _toDouble(property['purchase_price']);
    final String purchaseDate = (property['purchase_date'] ?? 'N/A').toString();
    final String status = (property['status'] ?? 'N/A').toString();
    final double paidPercent = property['paid_percent'] != null
        ? _toDouble(property['paid_percent'])
        : 0.0;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: () => _openPropertyDetailsModal(property, index),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: 14),

                    // info column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  estateName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sora(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                        color: _getStatusColor(status)
                                            .withOpacity(0.18),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6))
                                  ],
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.sora(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // chips row: plot size & number
                          Row(
                            children: [
                              _buildPropertyInfoItemWithChip(
                                  Icons.aspect_ratio, plotSize),
                              const SizedBox(width: 8),
                              _buildPropertyInfoItemWithChip(
                                  Icons.format_list_numbered, plotNumber),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // price summary
                          Text(
                            formatCurrency(purchasePrice, decimalDigits: 2),
                            style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),

                          const SizedBox(height: 6),

                          // mini progress if available
                          if (paidPercent > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                        '${paidPercent.toStringAsFixed(0)}% Paid',
                                        style: GoogleFonts.sora(
                                            fontSize: 12,
                                            color: Colors.grey[700])),
                                    const Spacer(),

                                    Text(
                                      'Balance: ${formatCurrency(_toDouble(purchasePrice) * (1 - (_toDouble(paidPercent) / 100)), decimalDigits: 2)}',
                                      style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600],
                                      ),
                                    ),

                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: (paidPercent / 100).clamp(0.0, 1.0),
                                    minHeight: 8,
                                    backgroundColor:
                                        Colors.grey.withOpacity(0.12),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        const Color(0xFF4154F1)),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Purchase Date',
                            style: GoogleFonts.sora(
                                fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Text(purchaseDate,
                            style: GoogleFonts.sora(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () {
                        final int? estateId = _extractEstateId(property);
                        final int? plotSizeId = _extractPlotSizeId(property);

                        if (estateId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Estate details not available for this property')),
                          );
                          return;
                        }

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ClientEstatePlotDetailsPage(
                              estateId: estateId,
                              token: widget.token,
                              plotSizeId: plotSizeId,
                            ),
                          ),
                        );
                      },

                      icon: const Icon(Icons.open_in_new),
                      label: Text('Plot Details', style: GoogleFonts.sora(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _openPropertyDetailsModal(property, index),
                      icon: const Icon(Icons.visibility, size: 16, color: Colors.white),
                      label:
                          Text('Transactions', style: GoogleFonts.sora(fontSize: 14, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4154F1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyInfoItemWithChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(text,
              style: GoogleFonts.sora(fontSize: 13, color: Colors.grey[800])),
        ],
      ),
    );
  }


  Widget _buildInfoChip(String label, String value) {
    return Chip(
      backgroundColor: Colors.grey[100],
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: GoogleFonts.sora(fontSize: 13, color: Colors.grey[700])),
        const SizedBox(width: 6),
        Text(value.isNotEmpty ? value : '—', style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }

  void _openPropertyDetailsModal(Map<String, dynamic> property, int index) {
    final api = ApiService();

    int? _extractTransactionId(Map<String, dynamic> p) {
      final cand = p['id'] ??
          p['transaction_id'] ??
          p['transactionId'] ??
          p['tx_id'] ??
          p['transaction'];
      if (cand == null) return null;
      if (cand is int) return cand;
      if (cand is String) return int.tryParse(cand);
      if (cand is Map && cand['id'] != null) {
        final id = cand['id'];
        if (id is int) return id;
        if (id is String) return int.tryParse(id);
      }
      return null;
    }

    final int? txId = _extractTransactionId(property);

    Future<Map<String, dynamic>> _fetchTxAndPayments(int id) async {
      final Map<String, dynamic> result = {
        'transaction': <String, dynamic>{},
        'payments': <dynamic>[]
      };
      try {
        final tx = await api.getTransactionDetail(token: widget.token, transactionId: id);
        result['transaction'] = tx ?? <String, dynamic>{};
      } catch (e) {
        result['transaction'] = <String, dynamic>{};
      }
      try {
        final payments = await api.getTransactionPayments(token: widget.token, transactionId: id);
        result['payments'] = payments ?? <dynamic>[];
      } catch (e) {
        result['payments'] = <dynamic>[];
      }
      return result;
    }

    String _safeString(dynamic v) {
      if (v == null) return '';
      return v.toString();
    }

    double _toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) {
        final cleaned = v.replaceAll(RegExp(r'[^0-9\.-]'), '');
        return double.tryParse(cleaned) ?? 0.0;
      }
      return 0.0;
    }

    String formatCurrency(num value, {int decimalDigits = 2}) {
      try {
        final f = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: decimalDigits);
        return f.format(value);
      } catch (e) {
        return '₦' + value.toStringAsFixed(decimalDigits);
      }
    }

    Color _getStatusColor(String status) {
      final s = status.toLowerCase();
      if (s.contains('paid') || s.contains('fully paid') || s.contains('paid complete')) return const Color(0xFF34c759);
      if (s.contains('overdue')) return Colors.red;
      if (s.contains('part')) return Colors.orange;
      return Colors.grey;
    }

    Future<void> _openReceiptAuthenticated({String? reference, int? txId}) async {
      final api = ApiService();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Downloading receipt...'),
              ],
            ),
          ),
        ),
      );

      try {
        File file;
        if (reference != null && reference.isNotEmpty) {
          file = await api.downloadReceiptByReference(
            token: widget.token,
            reference: reference,
            onProgress: (received, total) {},
            openAfterDownload: true,
          );
        } else if (txId != null) {
          file = await api.downloadReceiptByTransactionId(
            token: widget.token,
            transactionId: txId,
            onProgress: (r, t) {},
            openAfterDownload: true,
          );
        } else {
          throw Exception('No receipt reference or transaction id available');
        }

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Receipt saved: ${file.path}'))
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          try {
            if (reference != null && reference.isNotEmpty) {
              final uriRef = Uri.parse('${ApiService().baseUrl.replaceAll(RegExp(r'/api/?$'), '')}/payment/receipt/${Uri.encodeComponent(reference)}/');
              launchUrl(uriRef, mode: LaunchMode.externalApplication);
            } else if (txId != null) {
              final txUri = Uri.parse('${ApiService().baseUrl.replaceAll(RegExp(r'/api/?$'), '')}/transaction/$txId/receipt/');
              launchUrl(txUri, mode: LaunchMode.externalApplication);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Receipt not available: $e'))
              );
            }
          } catch (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Receipt download failed: $e'))
            );
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final String estateName = (property['estate_name'] ?? property['estate']?['name'] ?? 'Unknown Estate').toString();
            final double purchasePrice = _toDouble(property['purchase_price'] ?? property['total_amount'] ?? 0);
            final String purchaseDate = _safeString(property['purchase_date'] ?? property['transaction_date'] ?? '');
            final String status = (property['status'] ?? '').toString();

            final Future<Map<String, dynamic>>? combinedFuture = txId != null ? _fetchTxAndPayments(txId) : null;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 48, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: Text(estateName, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: _getStatusColor(status), borderRadius: BorderRadius.circular(20)),
                          child: Text(status.isNotEmpty ? status : 'Unknown', style: GoogleFonts.sora(fontSize: 13, color: Colors.white)),
                        )
                      ],
                    ),

                    const SizedBox(height: 12),
                    Text('Purchase Price', style: GoogleFonts.sora(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Text(formatCurrency(purchasePrice, decimalDigits: 2),
                        style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.grey[700])),
                    const SizedBox(height: 12),

                    Row(children: [
                      const Icon(Icons.calendar_today, size: 16),
                      const SizedBox(width: 8),
                      Text('Purchased on ${purchaseDate.isNotEmpty ? purchaseDate : 'N/A'}', style: GoogleFonts.sora(fontSize: 13, color: Colors.grey[800])),
                    ]),

                    const SizedBox(height: 18),
                    Text('Property Details', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 10, children: [
                      _buildInfoChip('Plot Number', property['plot_number']?.toString() ?? 'Reserved'),
                      _buildInfoChip('Plot Size', property['plot_size']?.toString() ?? 'N/A'),
                      _buildInfoChip('Estate', estateName),
                      // Receipt under estate name intentionally removed
                    ]),

                    const SizedBox(height: 20),

                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final int? estateId = _extractEstateId(property);
                            final int? plotSizeId = _extractPlotSizeId(property);

                            if (estateId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Estate details not available for this property')),
                              );
                              return;
                            }

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ClientEstatePlotDetailsPage(
                                  estateId: estateId,
                                  token: widget.token,
                                  plotSizeId: plotSizeId,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: Text('View Plot Details', style: GoogleFonts.sora()),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),
                    ]),

                    const SizedBox(height: 24),
                    Text('Transaction Details', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),

                    if (txId == null)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('No transaction id available for this property.', style: GoogleFonts.sora(color: Colors.grey[700])))
                    else
                      FutureBuilder<Map<String, dynamic>>(
                        future: combinedFuture,
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
                          }
                          if (snap.hasError) {
                            return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text('Failed to load transaction: ${snap.error}', style: GoogleFonts.sora(color: Colors.red)));
                          }

                          final data = snap.data ?? <String, dynamic>{};
                          final tx = (data['transaction'] is Map) ? Map<String, dynamic>.from(data['transaction']) : <String, dynamic>{};
                          List<dynamic> payments = List<dynamic>.from(data['payments'] ?? <dynamic>[]);

                          final double totalAmount = _toDouble(tx['total_amount'] ?? property['total_amount'] ?? property['purchase_price'] ?? 0);
                          final String txDate = _safeString(tx['transaction_date'] ?? property['transaction_date'] ?? '');
                          final String txStatus = _safeString(tx['status'] ?? property['status'] ?? '');
                          final String ref = _safeString(tx['reference_code'] ?? tx['reference'] ?? tx['receipt_number'] ?? '');

                          double totalPaid = 0.0;
                          for (final p in payments) {
                            totalPaid += _toDouble(p['amount'] ?? p['amount_paid'] ?? p['paid'] ?? 0);
                          }

                          final bool looksPaidByStatus = txStatus.toLowerCase().contains('paid') ||
                              txStatus.toLowerCase().contains('fully paid') ||
                              txStatus.toLowerCase().contains('paid complete');

                          final bool isFullAllocation = ((tx['allocation']?['payment_type'] ?? tx['payment_type'] ?? property['payment_type'])
                                  ?.toString()
                                  .toLowerCase() ==
                              'full');

                          final double computedBalance = (totalAmount - totalPaid);
                          const double zeroTolerance = 0.01;

                          if (looksPaidByStatus || isFullAllocation) {
                            totalPaid = totalAmount.clamp(0.0, double.infinity);

                            if (payments.isEmpty) {
                              final String syntheticRef = ref.isNotEmpty ? ref : (property['receipt_number']?.toString() ?? property['reference_code']?.toString() ?? '');
                              if (syntheticRef.isNotEmpty && totalAmount > 0) {
                                payments = [
                                  {
                                    'date': txDate,
                                    'amount_paid': totalAmount,
                                    'payment_method': tx['payment_method'] ?? property['payment_method'] ?? 'N/A',
                                    'receipt_number': syntheticRef,
                                    'reference_code': syntheticRef,
                                    'installment': null,
                                  }
                                ];
                              }
                            }
                          } else {
                            if (payments.isEmpty) {
                              final bool treatAsPaid = (computedBalance.abs() < zeroTolerance && totalAmount > 0);
                              final String syntheticRef = ref.isNotEmpty ? ref : (property['receipt_number']?.toString() ?? property['reference_code']?.toString() ?? '');
                              if (treatAsPaid && syntheticRef.isNotEmpty) {
                                payments = [
                                  {
                                    'date': txDate,
                                    'amount_paid': totalAmount,
                                    'payment_method': tx['payment_method'] ?? property['payment_method'] ?? 'N/A',
                                    'receipt_number': syntheticRef,
                                    'reference_code': syntheticRef,
                                    'installment': null,
                                  }
                                ];
                                totalPaid = totalAmount;
                              }
                            }
                          }

                          final double balance = (totalAmount - totalPaid).clamp(0.0, double.infinity);
                          final bool isZeroBalance = balance.abs() < zeroTolerance;

                          // compute payment type display value
                          final String paymentTypeValue = _safeString(tx['allocation']?['payment_type'] ?? tx['payment_type'] ?? property['payment_type'] ?? '');

                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // show only status chip (Total/Date rows removed as requested)
                            Row(children: [
                              Chip(backgroundColor: _getStatusColor(txStatus), label: Text(txStatus.isNotEmpty ? txStatus : 'Unknown', style: const TextStyle(color: Colors.white))),
                            ]),

                            const SizedBox(height: 12),

                            // PAYMENT TYPE (added back as requested)
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text('Payment Type', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
                              Text(paymentTypeValue.isNotEmpty ? paymentTypeValue : '—', style: GoogleFonts.sora()),
                            ]),
                            const SizedBox(height: 12),

                            // keep Total Paid / Balance
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Total Paid', style: GoogleFonts.sora(color: Colors.grey[700])),
                                const SizedBox(height: 6),
                                Text(formatCurrency(totalPaid, decimalDigits: 2), style: GoogleFonts.roboto(fontWeight: FontWeight.w700)),
                              ]),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text('Balance', style: GoogleFonts.sora(color: Colors.grey[700])),
                                const SizedBox(height: 6),
                                Text(formatCurrency(balance, decimalDigits: 2), style: GoogleFonts.roboto(fontWeight: FontWeight.w700, color: isZeroBalance ? Colors.green : Colors.red)),
                              ]),
                            ]),
                            const SizedBox(height: 18),

                            // === Installment / Part payment block (restored) ===
                            if ((_safeString(tx['allocation']?['payment_type'] ?? tx['payment_type'] ?? property['payment_type'] ?? '')).toLowerCase() == 'part') ...[
                              const SizedBox(height: 8),
                              Text('Installment Plan', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(
                                tx['installment_plan'] == 'custom'
                                    ? '${_safeString(tx['first_percent'])}%, ${_safeString(tx['second_percent'])}%, ${_safeString(tx['third_percent'])}%'
                                    : (_safeString(tx['installment_plan']).replaceAll('-', '%, ') + (tx['installment_plan'] != null ? '%' : '')),
                                style: GoogleFonts.sora(),
                              ),
                              const SizedBox(height: 8),
                              Wrap(spacing: 12, children: [
                                _buildInfoChip('1st', formatCurrency(_toDouble(tx['first_installment'] ?? 0))),
                                _buildInfoChip('2nd', formatCurrency(_toDouble(tx['second_installment'] ?? 0))),
                                _buildInfoChip('3rd', formatCurrency(_toDouble(tx['third_installment'] ?? 0))),
                              ]),
                              const SizedBox(height: 12),
                            ],
                            // === end installment block ===

                            Text('Payment Receipts', style: GoogleFonts.sora(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),

                            if (payments.isEmpty)
                              Text('No payment records found.', style: GoogleFonts.sora(color: Colors.grey[700]))
                            else
                              ListView.separated(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: payments.length,
                                separatorBuilder: (_, __) => const Divider(height: 8),
                                itemBuilder: (ctx, i) {
                                  final p = Map<String, dynamic>.from(payments[i] ?? <String, dynamic>{});
                                  final String date = _safeString(p['date'] ?? p['payment_date'] ?? '');
                                  final double amt = _toDouble(p['amount'] ?? p['amount_paid'] ?? p['paid'] ?? 0);
                                  final String method = _safeString(p['method'] ?? p['payment_method'] ?? '');
                                  final String receiptRef = _safeString(p['receipt_number'] ?? p['reference_code'] ?? p['reference'] ?? p['receipt'] ?? '');
                                  final int? installment = (p['installment'] is int) ? p['installment'] as int : (p['installment'] is String ? int.tryParse(p['installment']) : (p['selected_installment'] is int ? p['selected_installment'] as int : null));

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    leading: CircleAvatar(radius: 18, backgroundColor: Colors.grey[100], child: Text(installment != null ? installment.toString() : '-', style: GoogleFonts.sora())),
                                    title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(formatCurrency(amt, decimalDigits: 2), style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text('Ref: ${receiptRef.isNotEmpty ? receiptRef : '—'}', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[600])),
                                    ]),
                                    subtitle: Text('$method • ${date.isNotEmpty ? date : '—'}', style: GoogleFonts.sora(fontSize: 12)),
                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                      if (receiptRef.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 18),
                                          tooltip: 'Copy reference',
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: receiptRef));
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied to clipboard')));
                                          },
                                        ),
                                      if (receiptRef.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.download),
                                          tooltip: 'Download receipt PDF',
                                          onPressed: () async {
                                            final api = ApiService();
                                            final String? ref = receiptRef.isNotEmpty ? receiptRef : null;

                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (_) => WillPopScope(
                                                onWillPop: () async => false,
                                                child: AlertDialog(
                                                  content: Column(mainAxisSize: MainAxisSize.min, children: const [
                                                    CircularProgressIndicator(),
                                                    SizedBox(height: 12),
                                                    Text('Downloading receipt...'),
                                                  ]),
                                                ),
                                              ),
                                            );

                                            try {
                                              final File? file = await api.downloadReceiptWithFallback(
                                                token: widget.token,
                                                reference: ref,
                                                transactionId: txId,
                                                onProgress: (received, total) {},
                                                openAfterDownload: true,
                                              );

                                              if (mounted) {
                                                Navigator.of(context, rootNavigator: true).pop();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(file != null ? 'Receipt saved: ${file.path}' : 'Opened receipt in browser'))
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                Navigator.of(context, rootNavigator: true).pop();
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Receipt download failed: $e')));
                                              }
                                            }
                                          },
                                        ),
                                    ]),
                                  );
                                },
                              ),
                            const SizedBox(height: 12),
                          ]);
                        },
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAppreciationTab() {
    return FutureBuilder<dynamic>(
      future: _appreciationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildShimmerLoader();
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final data = snapshot.data;
        if (data == null) {
          return _emptyAppreciationPlaceholder();
        }

        // Normalization (keeps your original flexible parsing)
        List<dynamic> transactionsList = <dynamic>[];
        List<dynamic> seriesList = <dynamic>[];

        if (data is List) {
          transactionsList = data;
        } else if (data is Map) {
          final txs = data['transactions'] ?? data['transactions_list'] ?? data['results'] ?? data['data'] ?? data['items'];
          final s = data['series'] ?? data['points'];
          if (txs is List) transactionsList = txs;
          if (transactionsList.isEmpty) {
            for (final v in data.values) {
              if (v is List) {
                transactionsList = v;
                break;
              }
            }
          }
          if (s is List) seriesList = s;
        } else {
          return Center(child: Text('Unexpected data format from server'));
        }

        if (transactionsList.isEmpty) {
          return _emptyAppreciationPlaceholder();
        }

        // build normalized list and summary metrics
        final normalized = <Map<String, dynamic>>[];
        double totalAppreciation = 0.0;
        double totalGrowth = 0.0;
        double highestGrowth = double.negativeInfinity;
        String highestGrowthProperty = '';

        for (var raw in transactionsList) {
          final Map<String, dynamic> item =
              raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw as Map);
          final estateName = item['estate_name']?.toString() ??
              (item['estate'] is Map ? item['estate']['name']?.toString() : null) ??
              (item['allocation'] is Map
                  ? (item['allocation']['estate'] is Map
                      ? item['allocation']['estate']['name']?.toString()
                      : null)
                  : null) ??
              'Unknown Estate';
          final plotSize = item['plot_size']?.toString() ??
              (item['allocation'] is Map ? item['allocation']['plot_size']?.toString() : null) ??
              (item['allocation'] is Map && item['allocation']['plot_size'] is Map
                  ? item['allocation']['plot_size']['size']?.toString()
                  : null) ??
              'N/A';
          final purchasePrice =
              _toDouble(item['purchase_price'] ?? item['total_amount'] ?? item['total'] ?? 0);
          final currentValue =
              _toDouble(item['current_value'] ?? item['current'] ?? item['latest_price'] ?? purchasePrice);
          final appreciationTotal =
              _toDouble(item['appreciation'] ?? item['appreciation_total'] ?? (currentValue - purchasePrice));
          double growthRate;
          if (item['growth_rate'] != null) {
            growthRate = _toDouble(item['growth_rate']);
          } else if (purchasePrice > 0) {
            growthRate = ((currentValue - purchasePrice) / purchasePrice) * 100.0;
          } else {
            growthRate = 0.0;
          }
          double absGrowthRate = growthRate.abs();
          if (!absGrowthRate.isFinite) absGrowthRate = 0.0;
          if (absGrowthRate > 100.0) absGrowthRate = 100.0;

          DateTime? transactionDate;
          if (item['transaction_date'] != null) {
            try {
              transactionDate = DateTime.parse(item['transaction_date'].toString());
            } catch (_) {
              transactionDate = null;
            }
          }

          final norm = <String, dynamic>{
            'raw': item,
            'estate_name': estateName,
            'plot_size': plotSize,
            'purchase_price': purchasePrice,
            'current_value': currentValue,
            'appreciation_total': appreciationTotal,
            'growth_rate': growthRate,
            'abs_growth_rate': absGrowthRate,
            'transaction_date': transactionDate,
            'transaction_id': item['id'] ?? item['transaction_id'] ?? item['pk'],
            'receipt_number': item['receipt_number'] ?? item['receipt'] ?? item['raw_receipt'],
          };

          normalized.add(norm);

          totalAppreciation += appreciationTotal;
          totalGrowth += growthRate;
          if (growthRate > highestGrowth) {
            highestGrowth = growthRate;
            highestGrowthProperty = estateName;
          }
        }

        final averageGrowth = normalized.isNotEmpty ? totalGrowth / normalized.length : 0.0;

        // Responsive layout
        return LayoutBuilder(builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          int columns = 1;
          if (maxWidth >= 1200) columns = 3;
          else if (maxWidth >= 900) columns = 2;
          else columns = 1;

          const horizontalPadding = 16.0;
          const gap = 16.0;
          final availableWidth = maxWidth - (horizontalPadding * 2) - (gap * (columns - 1));
          final cardWidth = (availableWidth / columns).clamp(260.0, 560.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Property Value Appreciation',
                    style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Detailed view of property value growth over time',
                    style: GoogleFonts.sora(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: List.generate(normalized.length, (i) {
                    final item = normalized[i];
                    return SizedBox(width: cardWidth, child: _buildAppreciationCard(item, index: i));
                  }),
                ),
                const SizedBox(height: 22),
                LayoutBuilder(builder: (ctx, c) {
                  final isNarrow = c.maxWidth < 700;
                  return isNarrow
                      ? Column(
                          children: [
                            _buildSummaryCard(
                                title: 'Total Appreciation',
                                value: formatCurrency(totalAppreciation, forceSignForPositive: true),
                                icon: Icons.trending_up,
                                color: Colors.green),
                            const SizedBox(height: 12),
                            _buildSummaryCard(
                                title: 'Average Growth',
                                value: '${averageGrowth.toStringAsFixed(2)}%',
                                icon: Icons.percent,
                                color: Colors.blue),
                            const SizedBox(height: 12),
                            _buildSummaryCard(
                                title: 'Highest Growth',
                                value: highestGrowthProperty.isNotEmpty ? highestGrowthProperty : 'N/A',
                                subtitle:
                                    '+${highestGrowth.isFinite ? highestGrowth.toStringAsFixed(2) : '0.00'}%',
                                icon: Icons.star,
                                color: Colors.amber),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                  title: 'Total Appreciation',
                                  value: formatCurrency(totalAppreciation, forceSignForPositive: true),
                                  icon: Icons.trending_up,
                                  color: Colors.green),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                  title: 'Average Growth',
                                  value: '${averageGrowth.toStringAsFixed(2)}%',
                                  icon: Icons.percent,
                                  color: Colors.blue),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSummaryCard(
                                  title: 'Highest Growth',
                                  value: highestGrowthProperty.isNotEmpty ? highestGrowthProperty : 'N/A',
                                  subtitle:
                                      '+${highestGrowth.isFinite ? highestGrowth.toStringAsFixed(2) : '0.00'}%',
                                  icon: Icons.star,
                                  color: Colors.amber),
                            ),
                          ],
                        );
                }),
                const SizedBox(height: 18),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _emptyAppreciationPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 84, color: Colors.grey.shade300),
          const SizedBox(height: 18),
          Text('No Appreciation Data',
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Property appreciation data will appear here',
              style: GoogleFonts.sora(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _miniSparkline(double progress, Color color) {
    const int n = 7;
    final bars = List<Widget>.generate(n, (i) {
      final base = i / (n - 1);
      final amplitude = 0.30 + (0.6 * progress);
      final heightFactor = (0.30 + base * 0.70) * amplitude;
      final h = (12.0 + heightFactor * 36.0).clamp(8.0, 56.0);

      return Flexible(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withOpacity(0.98 - i * 0.06),
                  color.withOpacity(0.30 - i * 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      );
    });

    // area-like faded background to give "filled" impression (behind bars)
    return SizedBox(
      width: 132,
      height: 56,
      child: Stack(
        children: [
          // frothy area behind
          Align(
            alignment: Alignment.bottomLeft,
            child: FractionallySizedBox(
              widthFactor: 1.0,
              heightFactor: 0.6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withOpacity(0.12), color.withOpacity(0.02)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          // bars row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: bars),
          ),
          // small highlighted dot at the end to indicate "now"
          Positioned(
            right: 8,
            bottom: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppreciationCard(Map<String, dynamic> data, {int index = 0}) {
    final estateName = data['estate_name']?.toString() ?? 'Unknown Estate';
    final plotSize = data['plot_size']?.toString() ?? 'N/A';
    final purchasePrice = _toDouble(data['purchase_price']);
    final currentValue = _toDouble(data['current_value']);
    final appreciationTotal = _toDouble(data['appreciation_total']);
    final growthRate = _toDouble(data['growth_rate']);
    final absGrowthRate = _toDouble(data['abs_growth_rate']);
    final transactionDate = data['transaction_date'] as DateTime?;
    final purchaseLabel = transactionDate != null ? DateFormat('MMM yyyy').format(transactionDate) : 'Purchase';
    final progress = (absGrowthRate / 100.0).clamp(0.0, 1.0);

    final positive = growthRate >= 0;
    final accent = positive ? Colors.green : Colors.red;

    // card background: soft gradient + subtle "gloss" overlay
    final cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Theme.of(context).cardColor,
        Theme.of(context).cardColor.withOpacity(0.98),
      ],
    );

    // subtle tinted layer to give depth (you can tweak opacity)
    final tintGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [accent.withOpacity(0.06), Colors.transparent],
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.995, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.03)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8)),
            BoxShadow(color: Colors.white.withOpacity(0.02), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 150, maxHeight: 380),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {}, // visual only
              child: Stack(
                children: [
                  // tinted accent overlay
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: tintGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  // main content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // header row (accent bar + title)
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [accent.withOpacity(0.98), accent.withOpacity(0.65)],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(estateName,
                                    style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w900),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(plotSize, style: GoogleFonts.sora(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text('Estate', style: GoogleFonts.sora(fontSize: 11, color: Colors.grey)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // price row (stronger typography)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Purchase', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(formatCurrency(purchasePrice, decimalDigits: 2),
                                    style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w900)),
                              ),
                            ]),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text('Now', style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(formatCurrency(currentValue, decimalDigits: 2),
                                    style: GoogleFonts.roboto(fontSize: 15, fontWeight: FontWeight.w900, color: accent)),
                              ),
                            ]),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // row: value increase + small growth pill
                      Row(
                        children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Value Increase', style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              Text(
                                (appreciationTotal >= 0 ? '+' : '-') + formatCurrency(appreciationTotal.abs(), decimalDigits: 2),
                                style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: appreciationTotal >= 0 ? Colors.green : Colors.red),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ]),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(positive ? Icons.trending_up : Icons.trending_down, size: 14, color: accent),
                                const SizedBox(width: 6),
                                Text('${growthRate >= 0 ? '+' : '-'}${growthRate.abs().toStringAsFixed(2)}%',
                                    style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w800, color: accent)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // sparkline + labels row (compact)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _miniSparkline(progress, accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('From', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(purchaseLabel, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('Current', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(formatCurrency(currentValue, decimalDigits: 2),
                                style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w800)),
                          ]),
                        ],
                      ),
                    ],
                  ),

                  // floating badge (smaller, more elegant)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accent.withOpacity(0.98), accent.withOpacity(0.72)],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: accent.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Icon(positive ? Icons.trending_up : Icons.trending_down, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('${growthRate >= 0 ? '+' : '-'}${growthRate.abs().toStringAsFixed(1)}%',
                              style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      child: Text(value,
                          key: ValueKey(value),
                          style: GoogleFonts.sora(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: color,
                          ).copyWith(
                            fontFamilyFallback: const ['Arial', 'Roboto', 'sans-serif'],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 8),
                    Text(subtitle, style: GoogleFonts.sora(fontSize: 13, color: Colors.grey)),
                  ]
                ],
              ),
            ]),
          )
        ],
      ),
    );
  }

  Widget _buildEditProfileTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildShimmerLoader();
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final profile = snapshot.data!;

        // Initialize controllers once (keeps user edits across rebuilds)
        if (!_isEditing) {
          _fullNameController.text = (profile['full_name'] ?? '').toString();
          _aboutController.text = (profile['about'] ?? '').toString();
          _companyController.text = (profile['company'] ?? '').toString();
          _jobController.text = (profile['job'] ?? '').toString();
          _countryController.text = (profile['country'] ?? '').toString(); // <- ensure country is set
          _addressController.text = (profile['address'] ?? '').toString();
          _phoneController.text = (profile['phone'] ?? '').toString();
          _emailController.text = (profile['email'] ?? '').toString();
          _isEditing = true;
        }

        Widget _input({
          required TextEditingController controller,
          required String label,
          required IconData icon,
          bool enabled = true,
          TextInputType? keyboardType,
          int maxLines = 1,
          Widget? suffix,
          String? hint,
          String? Function(String?)? validator,
        }) {
          final fill = enabled ? Colors.white : Colors.grey.shade50;
          final textColor = enabled ? null : Colors.grey.shade700;
          return TextFormField(
            controller: controller,
            enabled: enabled,
            readOnly: !enabled,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.sora(color: textColor),
            validator: (v) {
              if (!enabled) return null;
              if (validator != null) return validator(v);
              return null;
            },
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(icon, color: Colors.grey.shade600),
              suffixIcon: suffix,
              filled: true,
              fillColor: fill,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4154F1), width: 1.4),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.withOpacity(0.06)),
              ),
            ),
          );
        }

        return Container(
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 10))],
                    border: Border.all(color: Colors.grey.withOpacity(0.06)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.grey.shade100,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (profile['profile_image'] != null
                                    ? NetworkImage(profile['profile_image'] as String)
                                    : const AssetImage('assets/avater.webp')) as ImageProvider,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF4154F1), Color(0xFF6C7BFF)]),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              onPressed: _pickImage,
                              tooltip: 'Change profile picture',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(width: 16),

                      // Info area (uses Expanded to avoid overflow)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fullNameController.text.isNotEmpty ? _fullNameController.text : 'Your name',
                              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w900),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Chips area
                            LayoutBuilder(builder: (ctx, c) {
                              return ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: c.maxWidth),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (_jobController.text.isNotEmpty)
                                      Chip(
                                        backgroundColor: Colors.grey.shade50,
                                        label: Text(_jobController.text, style: GoogleFonts.sora(fontSize: 12, color: Colors.grey.shade800)),
                                      ),
                                    if (_companyController.text.isNotEmpty)
                                      Chip(
                                        backgroundColor: Colors.grey.shade50,
                                        label: Text(_companyController.text, style: GoogleFonts.sora(fontSize: 12, color: Colors.grey.shade800)),
                                      ),
                                    Chip(
                                      backgroundColor: Colors.grey.shade50,
                                      label: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(_countryController.text.isNotEmpty ? _countryController.text : 'Country', style: GoogleFonts.sora(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const SizedBox(height: 8),
                            Text(
                              _aboutController.text.isNotEmpty ? _aboutController.text : 'A short friendly bio will appear here.',
                              style: GoogleFonts.sora(fontSize: 13, color: Colors.grey.shade700),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Form card
                Form(
                  key: _formKey,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 6))],
                      border: Border.all(color: Colors.grey.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // About Me
                        Text('About Me', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        _input(
                          controller: _aboutController,
                          label: 'Your Bio',
                          icon: Icons.edit,
                          enabled: true,
                          maxLines: 5,
                          hint: 'e.g. Who you are...',
                        ),
                        const SizedBox(height: 14),

                        // Responsive two-column section (fields)
                        LayoutBuilder(builder: (ctx, constraints) {
                          final twoCol = constraints.maxWidth >= 680;
                          if (twoCol) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left column
                                Expanded(
                                  child: Column(children: [
                                    _input(
                                      controller: _fullNameController,
                                      label: 'Full Name',
                                      icon: Icons.person,
                                      enabled: false,
                                    ),
                                    const SizedBox(height: 12),
                                    _input(controller: _companyController, label: 'Company', icon: Icons.business),
                                    const SizedBox(height: 12),
                                    // Country field (editable here)
                                    _input(controller: _countryController, label: 'Country', icon: Icons.flag, enabled: true, keyboardType: TextInputType.text),
                                  ]),
                                ),
                                const SizedBox(width: 12),

                                // Right column
                                Expanded(
                                  child: Column(children: [
                                    _input(
                                      controller: _emailController,
                                      label: 'Email',
                                      icon: Icons.email,
                                      enabled: false,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 12),
                                    _input(controller: _jobController, label: 'Job Title', icon: Icons.work),
                                    const SizedBox(height: 12),
                                    _input(
                                      controller: _phoneController,
                                      label: 'Phone',
                                      icon: Icons.phone,
                                      enabled: false,
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ]),
                                ),
                              ],
                            );
                          } else {
                            return Column(children: [
                              _input(controller: _fullNameController, label: 'Full Name', icon: Icons.person, enabled: false),
                              const SizedBox(height: 12),
                              _input(controller: _emailController, label: 'Email', icon: Icons.email, enabled: false, keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 12),
                              _input(controller: _companyController, label: 'Your Company', icon: Icons.business),
                              const SizedBox(height: 12),
                              _input(controller: _jobController, label: 'Your Job Title', icon: Icons.work),
                              const SizedBox(height: 12),
                              // Country input for small screens (editable)
                              _input(controller: _countryController, label: 'Country', icon: Icons.flag, enabled: true, keyboardType: TextInputType.text),
                              const SizedBox(height: 12),
                              _input(controller: _phoneController, label: 'Phone', icon: Icons.phone, enabled: false, keyboardType: TextInputType.phone),
                            ]);
                          }
                        }),

                        const SizedBox(height: 14),

                        _input(controller: _addressController, label: 'Address', enabled: false, icon: Icons.location_on),

                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _updateProfile,
                            style: ButtonStyle(
                              padding: MaterialStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                              shape: MaterialStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              elevation: MaterialStateProperty.all(8),
                              shadowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.18)),
                              backgroundColor: MaterialStateProperty.resolveWith((states) {
                                return Colors.transparent;
                              }),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF4A6DF5), Color(0xFF4154F1)]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                alignment: Alignment.center,
                                constraints: const BoxConstraints(minHeight: 48),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.save, color: Colors.white, size: 18),
                                    const SizedBox(width: 10),
                                    Text('Save Changes', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔒 Change Password',
              style: GoogleFonts.sora(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1D2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Keep your account secure by choosing a strong password.',
              style: GoogleFonts.sora(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),

            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildPasswordField(
                    controller: _currentPasswordController,
                    label: 'Current Password',
                    icon: Icons.lock,
                    isVisible: _currentVisible,
                    toggleVisibility: () {
                      setState(() => _currentVisible = !_currentVisible);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your current password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    icon: Icons.lock_outline,
                    isVisible: _newVisible,
                    toggleVisibility: () {
                      setState(() => _newVisible = !_newVisible);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm New Password',
                    icon: Icons.lock_reset,
                    isVisible: _confirmVisible,
                    toggleVisibility: () {
                      setState(() => _confirmVisible = !_confirmVisible);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password';
                      }
                      if (value != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4154F1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Change Password',
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback toggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF4154F1)),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.grey,
          ),
          onPressed: toggleVisibility,
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildStatsRow(
      {required int propertiesCount, required double totalValue}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem(
          value: propertiesCount.toString(),
          label: 'Properties',
        ),
        Container(
          height: 30,
          width: 1,
          color: Colors.grey[300],
          margin: const EdgeInsets.symmetric(horizontal: 20),
        ),
        _buildStatItem(
          value: '₦${totalValue.toStringAsFixed(2)}',
          label: 'Total Value',
        ),
      ],
    );
  }

  Widget _buildStatItem({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.sora(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF4154F1),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final propertiesCount = _toInt(profile['properties_count']);
    final totalValue = _toDouble(profile['total_value']);
    final avatarUrl = profile['profile_image'] as String?;

    final dynamic assignedRaw = profile['assigned_marketer'];
    Map<String, dynamic>? assigned;

    if (assignedRaw == null) {
      assigned = null;
    } else if (assignedRaw is Map<String, dynamic>) {
      assigned = Map<String, dynamic>.from(assignedRaw);
    } else if (assignedRaw is Map) {
      assigned = Map<String, dynamic>.from(assignedRaw.map((k, v) => MapEntry(k.toString(), v)));
    } else {
      assigned = null;
    }


    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.85),
              Colors.white.withOpacity(0.72),
            ],
            stops: const [0.0, 0.9],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: const Color(0xFF4154F1).withOpacity(0.06),
              blurRadius: 40,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.6)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_tabController.index != 0) _tabController.animateTo(0);
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                // Use LayoutBuilder here to make stats area responsive
                child: LayoutBuilder(builder: (context, constraints) {
                  // compute a responsive max width for the mini chart
                  final double maxChartWidth =
                      (constraints.maxWidth * 0.28).clamp(60.0, 110.0);

                  return Column(
                    children: [
                      // header row: avatar + name + marketer badge (animated)
                      Row(
                        children: [
                          Hero(
                            tag: 'profile-image',
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF4154F1).withOpacity(0.12),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? FadeInImage.assetNetwork(
                                        placeholder:
                                            'assets/avater.webp',
                                        image: avatarUrl,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.asset(
                                        'assets/avater.webp',
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile['full_name'] ?? 'Valued Client',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sora(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  profile['company'] ?? profile['job'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sora(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // <-- changed Row to Wrap so badges don't force overflow -->
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _buildRankBadge(profile['rank_tag'] ?? 'First-Time Investor'),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 450),
                                      switchInCurve: Curves.easeOutBack,
                                      child: assigned != null
                                          ? _buildMarketerBadge(assigned)
                                          : SizedBox(
                                              key:
                                                  const ValueKey('no_marketer'),
                                              child: Text(
                                                'No marketer assigned',
                                                style: GoogleFonts.sora(
                                                    fontSize: 12,
                                                    color: Colors.grey),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Animated stats row with a mini chart
                      Row(
                        children: [
                          Flexible(
                            flex: 1,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                  begin: 0, end: propertiesCount.toDouble()),
                              duration: const Duration(milliseconds: 900),
                              builder: (context, value, child) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      value.toInt().toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.sora(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF4154F1),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Properties',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.sora(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),

                          // thin divider (keeps fixed width 1)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Container(
                                height: 36, width: 1, color: Colors.grey[200]),
                          ),

                          Flexible(
                            flex: 1,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: totalValue),
                              duration: const Duration(milliseconds: 1100),
                              builder: (context, value, child,) {
                                final display = value >= 1000
                                    ? formatCurrency(value, decimalDigits: 0)
                                    : formatCurrency(value, decimalDigits: 2);
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      left: 4.0, right: 4.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        display,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.roboto(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total Investment',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey)
                                      ),
                                    ],
                                  ),
                                );
                              },
                            
                            ),
                          ),

                          // mini sparkline chart (visual hint)
                          SizedBox(
                            width: maxChartWidth,
                            height: 56,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: SfCartesianChart(
                                margin: EdgeInsets.zero,
                                plotAreaBorderWidth: 0,
                                primaryXAxis: CategoryAxis(isVisible: false),
                                primaryYAxis: NumericAxis(isVisible: false),
                                series: <ChartSeries>[
                                  LineSeries<Map<String, dynamic>, String>(
                                    dataSource: [
                                      {'y': (totalValue * 0.85)},
                                      {'y': (totalValue * 0.95)},
                                      {'y': (totalValue * 1.05)},
                                      {'y': totalValue},
                                    ],
                                    xValueMapper: (Map<String, dynamic> d, _) =>
                                        _.toString(),
                                    yValueMapper: (Map<String, dynamic> d, _) =>
                                        _toDouble(d['y']),
                                    width: 2,
                                    markerSettings:
                                        const MarkerSettings(isVisible: false),
                                    color: const Color(0xFF4154F1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketerBadge(Map<String, dynamic>? marketer) {
    if (marketer == null) return const SizedBox.shrink();

    final String name = (marketer['full_name']?.toString().trim().isNotEmpty == true)
        ? marketer['full_name'].toString().trim()
        : (marketer['name']?.toString().trim().isNotEmpty == true ? marketer['name'].toString().trim() : 'Not assigned');

    // Grab any of the commonly used keys and trim whitespace
    String? avatarUrl = (marketer['profile_image'] as String?)?.trim();
    avatarUrl ??= (marketer['avatar'] as String?)?.trim();
    avatarUrl ??= (marketer['image'] as String?)?.trim();

    bool _looksLikeAbsoluteUrl(String? s) {
      if (s == null || s.isEmpty) return false;
      final uri = Uri.tryParse(s);
      return uri != null && (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') || s.startsWith('//'));
    }

    // If you want to support relative URLs (e.g. "/media/..."), provide a baseUrl from your config.
    // If you have a global ApiService.baseUrl, you can uncomment and use the block below:
    //
    // if (avatarUrl != null && !_looksLikeAbsoluteUrl(avatarUrl)) {
    //   final prefix = ApiService.baseUrl?.endsWith('/') == true ? ApiService.baseUrl!.substring(0, ApiService.baseUrl!.length - 1) : ApiService.baseUrl ?? '';
    //   if (prefix.isNotEmpty) {
    //     avatarUrl = avatarUrl.startsWith('/') ? '$prefix$avatarUrl' : '$prefix/$avatarUrl';
    //   }
    // }

    // Build avatar widget with safe error handling
    Widget avatarWidget;
    if (_looksLikeAbsoluteUrl(avatarUrl)) {
      avatarWidget = ClipOval(
        child: Image.network(
          avatarUrl!,
          width: 24,
          height: 24,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              width: 24,
              height: 24,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // fallback to local asset if network fails
            return Image.asset('assets/avater.webp', width: 24, height: 24, fit: BoxFit.cover);
          },
        ),
      );
    } else {
      // Not an absolute URL -> use local asset fallback
      avatarWidget = ClipOval(
        child: Image.asset('assets/avater.webp', width: 24, height: 24, fit: BoxFit.cover),
      );
    }

    return AnimatedContainer(
      key: ValueKey(name),
      duration: const Duration(milliseconds: 520),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4154F1), Color(0xFF7F8CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 24, height: 24, child: avatarWidget),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Marketer',
                style: GoogleFonts.sora(fontSize: 10, color: Colors.white.withOpacity(0.9)),
              ),
              Text(
                name,
                style: GoogleFonts.sora(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(String rankTag) {
    // Define rank styling based on rank tier
    Map<String, dynamic> getRankStyle(String rank) {
      switch (rank) {
        case 'Royal Elite':
          return {
            'icon': Icons.diamond,
            'gradient': [const Color(0xFF6a11cb), const Color(0xFF2575fc)],
            'shadowColor': const Color(0xFF2575fc).withOpacity(0.25),
          };
        case 'Estate Ambassador':
          return {
            'icon': Icons.military_tech,
            'gradient': [const Color(0xFFfbbf24), const Color(0xFFf59e0b)],
            'shadowColor': const Color(0xFFf59e0b).withOpacity(0.25),
          };
        case 'Prime Investor':
          return {
            'icon': Icons.trending_up,
            'gradient': [const Color(0xFF3b82f6), const Color(0xFF06b6d4)],
            'shadowColor': const Color(0xFF06b6d4).withOpacity(0.25),
          };
        case 'Smart Owner':
          return {
            'icon': Icons.lightbulb,
            'gradient': [const Color(0xFF10b981), const Color(0xFF34d399)],
            'shadowColor': const Color(0xFF10b981).withOpacity(0.25),
          };
        case 'First-Time Investor':
        default:
          return {
            'icon': Icons.emoji_events,
            'gradient': [const Color(0xFF8b5cf6), const Color(0xFFa78bfa)],
            'shadowColor': const Color(0xFF8b5cf6).withOpacity(0.25),
          };
      }
    }

    final style = getRankStyle(rankTag);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: style['gradient'] as List<Color>,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: style['shadowColor'] as Color,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style['icon'] as IconData,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            rankTag,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.sora(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard(Map<String, dynamic> profile) {
    final email = profile['email'] ?? 'Not specified';
    final phone = profile['phone'] ?? 'Not specified';
    final address = profile['address'] ?? 'Not specified';
    final company = profile['company'] ?? 'Not specified';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 18,
                offset: const Offset(0, 12))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Contact Information',
                    style: GoogleFonts.sora(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              _buildContactItem(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: email,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: email));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Email copied to clipboard')));
                  }),
              _buildContactItem(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: phone,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Phone copied to clipboard')));
                  }),
              _buildContactItem(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: address,
                  onTap: () {}),
              _buildContactItem(
                  icon: Icons.business_outlined,
                  label: 'Company',
                  value: company,
                  onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    GestureTapCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4154F1).withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF4154F1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.sora(
                            fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 2),
                    Text(value,
                        style: GoogleFonts.sora(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
            ),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(Icons.copy, size: 16, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetails(Map<String, dynamic> profile) {
    final about = profile['about'] as String? ?? 'No information provided';
    final rawDate = profile['date_registered'];
    String dateRegistered;
    if (rawDate == null) {
      dateRegistered = 'Not specified';
    } else {
      final s = rawDate.toString();
      String datePart;
      if (s.contains('T')) {
        datePart = s.split('T')[0];
      } else if (s.contains(' ')) {
        datePart = s.split(' ')[0];
      } else {
        datePart = s;
      }
      try {
        final dt = DateTime.parse(datePart);
        dateRegistered = DateFormat.yMMMMd().format(dt);
      } catch (_) {
        dateRegistered = datePart;
      }
    }

    final country = profile['country']?.toString() ?? 'Not specified';
    final fullName = profile['full_name']?.toString() ?? 'Not specified';

    bool isLong = about.length > 140;
    final preview = isLong ? '${about.substring(0, 140)}…' : about;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 18,
              offset: const Offset(0, 12),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // determine columns based on available width
              final cols = constraints.maxWidth > 600 ? 3 : 2;
              const gap = 12.0;
              // tile width calculation accounts for gaps between items
              final tileWidth =
                  (constraints.maxWidth - (gap * (cols - 1))) / cols;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'About Me',
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            _tabController.animateTo(3);
                          },
                          icon: const Icon(Icons.edit_outlined,
                              color: Color(0xFF4154F1)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedCrossFade(
                      firstChild: Text(
                        preview,
                        style: GoogleFonts.sora(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                      ),
                      secondChild: Text(
                        about,
                        style: GoogleFonts.sora(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[800],
                        ),
                      ),
                      crossFadeState: about.length > 140
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 450),
                    ),
                    if (isLong)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('About Me', style: GoogleFonts.sora()),
                                content: Text(about, style: GoogleFonts.sora()),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: Text(
                                      'Close',
                                      style: GoogleFonts.sora(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Text(
                            'Read more',
                            style: GoogleFonts.sora(
                              color: const Color(0xFF4154F1),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Profile Details',
                      style: GoogleFonts.sora(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Responsive wrap in place of GridView to avoid overflow and allow tile content to wrap
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: _buildInfoItem(
                              label: 'Full Name', value: fullName),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child:
                              _buildInfoItem(label: 'Country', value: country),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: _buildInfoItem(
                              label: 'Date Registered', value: dateRegistered),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPortfolioSummaryCard(
                      propertiesCount: _toInt(profile['properties_count']),
                      totalValue: _toDouble(profile['total_value']),
                      currentValue: _toDouble(profile['current_value']),
                      appreciationTotal:
                          _toDouble(profile['appreciation_total']),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 6),
          Text(value,
              style:
                  GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildPortfolioSummaryCard({
    required int propertiesCount,
    required double totalValue,
    required double currentValue,
    required double appreciationTotal,
  }) {
    // ensure values are finite and safe
    totalValue = totalValue.isFinite ? totalValue : 0.0;
    currentValue = currentValue.isFinite ? currentValue : 0.0;
    appreciationTotal = appreciationTotal.isFinite ? appreciationTotal : 0.0;

    final growthPercent = totalValue > 0
        ? ((currentValue - totalValue) / (totalValue) * 100)
            .clamp(-999.0, 9999.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Portfolio Summary',
            style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildSummaryItem(
            label: 'Total Properties', value: propertiesCount.toString()),
        _buildSummaryItem(
            label: 'Total Investment',
            // value: '₦${totalValue.toStringAsFixed(2)}'),
            value: formatCurrency(totalValue, decimalDigits: 2)),
        _buildSummaryItem(
            label: 'Current Value',
            // value: '₦${currentValue.toStringAsFixed(2)}'),
            value: formatCurrency(currentValue, decimalDigits: 2)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: (currentValue > 0 && totalValue > 0)
                    ? (currentValue / (totalValue * 1.15)).clamp(0.0, 1.0)
                    : 0.0,
                minHeight: 8,
                backgroundColor: Colors.grey.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(growthPercent >= 0
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444)),
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(
                  growthPercent.isFinite
                      ? '${growthPercent.toStringAsFixed(2)}%'
                      : '0.00%',
                  style: GoogleFonts.sora(fontWeight: FontWeight.w700)),
              Text('growth',
                  style:
                      GoogleFonts.sora(fontSize: 12, color: Colors.grey[600])),
            ]),
          ],
        ),
        const SizedBox(height: 8),
        _buildSummaryItem(
            label: 'Total Appreciation',
            value: formatCurrency(appreciationTotal, decimalDigits: 2),
            isPositive: appreciationTotal >= 0),
      ]),
    );
  }

 
  Widget _buildSummaryItem({
    required String label,
    required dynamic value,
    bool isPositive = false,
    int? decimalDigits,
  }) {
    final formattedValue = value is String
        ? value
        : formatCurrency(value, decimalDigits: decimalDigits ?? 2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[700]),
          ),
          Text(
            formattedValue,
            style: GoogleFonts.roboto(
              fontWeight: FontWeight.w800,
              color: isPositive
                  ? const Color(0xFF10B981)
                  : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildShimmerLoader() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
              height: 140,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16))),
        ),
        const SizedBox(height: 14),
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Row(children: [
            Expanded(
                child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)))),
            const SizedBox(width: 12),
            Expanded(
                child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)))),
          ]),
        ),
        const SizedBox(height: 14),
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
              height: 220,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16))),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}


