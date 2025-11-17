import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:real_estate_app/shared/app_side.dart';
import 'package:shimmer/shimmer.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/shared/app_layout.dart';
import 'package:real_estate_app/marketer/marketer_bottom_nav.dart';

class MarketerProfile extends StatefulWidget {
  final String token;

  const MarketerProfile({Key? key, required this.token}) : super(key: key);

  @override
  _MarketerProfileState createState() => _MarketerProfileState();
}

class _MarketerProfileState extends State<MarketerProfile>
    with TickerProviderStateMixin {
  String? _headerImageUrl;
  late final AnimationController _glowController;
  final Map<int, NumberFormat> _currencyFormatCache = {};
  bool _currentVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;

  late TabController _tabController;
  late Future<Map<String, dynamic>> _profileFuture;

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;

  // profile cache used across tabs
  Map<String, dynamic> _profileData = {};

  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _jobController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // ---------------- util/parsers ----------------
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(',', '');
      return double.tryParse(cleaned) ?? 0.0;
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
      try {
        return (double.parse(v.toString())).toInt();
      } catch (_) {
        return 0;
      }
    }
  }

  String formatCurrency(dynamic valueOrDouble,
      {int? decimalDigits, String locale = 'en_NG'}) {
    final double value =
        valueOrDouble is double ? valueOrDouble : _toDouble(valueOrDouble);
    final digits = decimalDigits ?? (value.abs() >= 1000 ? 0 : 2);

    final fmt = _currencyFormatCache.putIfAbsent(digits, () {
      return NumberFormat.currency(
        locale: locale,
        symbol: '\u20A6',
        decimalDigits: digits,
      );
    });

    try {
      return fmt.format(value);
    } catch (_) {
      return '\u20A6${value.toStringAsFixed(digits)}';
    }
  }

  // ---------------- lifecycle ----------------
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadProfile();
  }

  void _loadProfile() {
    _profileFuture =
        ApiService().getMarketerProfileByToken(token: widget.token).then((data) {
      // hydrate header and cache
      final maybeHeader = (data['header_image'] ?? data['profile_image']);
      if (maybeHeader is String && maybeHeader.isNotEmpty) {
        _headerImageUrl = maybeHeader;
      }
      _profileData = Map<String, dynamic>.from(data);
      // prefill controllers
      _companyController.text = _profileData['company'] ?? '';
      _jobController.text = _profileData['job'] ?? '';
      _fullNameController.text = _profileData['full_name'] ?? '';
      _aboutController.text = _profileData['about'] ?? '';
      _countryController.text = _profileData['country'] ?? '';
      _addressController.text = _profileData['address'] ?? '';
      _phoneController.text = _profileData['phone'] ?? '';
      _emailController.text = _profileData['email'] ?? '';

      return data;
    });
  }

  @override
  void dispose() {
    _companyController.dispose();
    _jobController.dispose();
    _tabController.dispose();
    _glowController.dispose();
    _fullNameController.dispose();
    _aboutController.dispose();
    _countryController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------- image & API interactions ----------------
  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submitProfileUpdate() async {
    // According to DRF view: allowed updatable fields: about, company, job, country, profile_image
    if (!_formKey.currentState!.validate()) return;

    try {
      final updated = await ApiService().updateMarketerProfileDetails(
        token: widget.token,
        company: _companyController.text,
        job: _jobController.text,
        about: _aboutController.text,
        country: _countryController.text,
        profileImage: _imageFile,
      );

      // update local state
      setState(() {
        _profileData = Map<String, dynamic>.from(updated);
        _imageFile = null;
        final maybeHeader = (updated['header_image'] ?? updated['profile_image']);
        if (maybeHeader is String && maybeHeader.isNotEmpty) _headerImageUrl = maybeHeader;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Profile updated successfully', style: GoogleFonts.sora(color: Colors.white)),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error updating profile: $e', style: GoogleFonts.sora(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _submitPasswordChange() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Passwords do not match', style: GoogleFonts.sora(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
      return;
    }

    try {
      await ApiService().changeMarketerPassword(
        token: widget.token,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Password updated successfully', style: GoogleFonts.sora(color: Colors.white)),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error changing password: $e', style: GoogleFonts.sora(color: Colors.white)),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final data = await ApiService().getMarketerProfileByToken(token: widget.token);
      // update UI in one setState
      setState(() {
        _profileData = Map<String, dynamic>.from(data);
        _profileFuture = Future.value(data);

        // update header image if present
        final maybeHeader = (data['header_image'] ?? data['profile_image']);
        if (maybeHeader is String && maybeHeader.isNotEmpty) {
          _headerImageUrl = maybeHeader;
        } else {
          _headerImageUrl = null;
        }

        // Prefill controllers exactly as done in _loadProfile
        _companyController.text = _profileData['company'] ?? '';
        _jobController.text = _profileData['job'] ?? '';
        _fullNameController.text = _profileData['full_name'] ?? '';
        _aboutController.text = _profileData['about'] ?? '';
        _countryController.text = _profileData['country'] ?? '';
        _addressController.text = _profileData['address'] ?? '';
        _phoneController.text = _profileData['phone'] ?? '';
        _emailController.text = _profileData['email'] ?? '';

        // Clear any picked-but-not-saved image preview (optional)
        _imageFile = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return AppLayout(
      pageTitle: 'Profile',
      token: widget.token,
      side: AppSide.marketer,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          bottomNavigationBar:
              MarketerBottomNav(currentIndex: 1, token: widget.token, chatBadge: 0),
          body: NestedScrollView(
            floatHeaderSlivers: true,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              final double topPadding = MediaQuery.of(context).padding.top;
              final double expandedHeight = 280.0 + topPadding;

              return [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  stretch: true,
                  expandedHeight: expandedHeight,
                  automaticallyImplyLeading: false,
                  centerTitle: false,
                  toolbarHeight: kToolbarHeight + topPadding,
                  collapsedHeight: kToolbarHeight + topPadding,
                  flexibleSpace: LayoutBuilder(builder: (context, constraints) {
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
                    final double smallTitleLeft = smallTitleLeftCollapsed +
                        (smallTitleLeftExpanded - smallTitleLeftCollapsed) * t;

                    final Widget backgroundImageWidget =
                        (_headerImageUrl != null && _headerImageUrl!.isNotEmpty)
                            ? Image.network(
                                _headerImageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (c, child, progress) {
                                  if (progress == null) return child;
                                  return Container(color: Colors.grey[300]);
                                },
                                errorBuilder: (c, e, s) =>
                                    Image.asset('assets/avater.webp',
                                        fit: BoxFit.cover),
                              )
                            : Image.asset('assets/avater.webp',
                                fit: BoxFit.cover);

                    final double glowScale =
                        0.85 + (_glowController.value) * (1.35 - 0.85);
                    final double glowFactor = glowScale * (0.7 + 0.3 * t);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned.fill(child: backgroundImageWidget),
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
                                  offset:
                                      Offset(0, 6 * (1.0 - t) + 2),
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
                                            loadingBuilder:
                                                (c, child, progress) {
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
                  }),
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
                        Tab(text: 'Details'),
                        Tab(text: 'Performance'),
                        Tab(text: 'Top Performers'),
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
                _detailsTab(),
                _performanceTab(),
                _topPerformersTab(),
                _editProfileTab(),
                _passwordTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- Tab: Details ----------------
  Widget _detailsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoader();
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final profile = snap.data!;
        if (_profileData.isEmpty) _profileData = Map<String, dynamic>.from(profile);

        return RefreshIndicator(
          onRefresh: _refreshProfile,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildProfileCard(profile),
                      const SizedBox(height: 12),
                      _buildProfileDetails(profile),
                      const SizedBox(height: 12),
                      _buildContactInfoCard(profile),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  
  }

  Widget _detailRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Icon(icon, color: const Color(0xFF2575FC)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: GoogleFonts.sora(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(value, textAlign: TextAlign.right, style: GoogleFonts.sora(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ---------------- Performance Tab ----------------
  Widget _performanceTab() {
    // Use cached profile if available, else fallback to FutureBuilder to wait for initial load
    if (_profileData.isEmpty) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) return _buildShimmerLoader();
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          _profileData = Map<String, dynamic>.from(s.data!);
          return _performanceContent(_profileData);
        },
      );
    } else {
      return _performanceContent(_profileData);
    }
  }

  Widget _performanceContent(Map<String, dynamic> profile) {
    final performance = (profile['performance'] as Map<String, dynamic>?) ?? {};
    final currentYear = profile['current_year'] ?? DateTime.now().year;

    final closedDeals = _toInt(performance['closed_deals']);
    final commissionEarned = _toDouble(performance['commission_earned']);
    final commissionRate = (_toDouble(performance['commission_rate']).clamp(0.0, 100.0));
    final yearlyTargetAchievementRaw = performance['yearly_target_achievement'];
    final yearlyTargetAchievement = yearlyTargetAchievementRaw != null ? _toDouble(yearlyTargetAchievementRaw).clamp(0.0, 100.0) : null;

    // animation durations
    const animDur = Duration(milliseconds: 900);
    const delayShort = Duration(milliseconds: 120);

    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 720;
      // clamp sizes relative to available width
      final circleSmall = (isNarrow ? 56.0 : 64.0).clamp(56.0, 80.0);
      final circleBig = (isNarrow ? 96.0 : 120.0).clamp(80.0, 140.0);

      Widget closedDealsCard() => TweenAnimationBuilder<double>(
        duration: animDur,
        tween: Tween(begin: 0.0, end: closedDeals.toDouble()),
        builder: (context, value, child) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [Colors.white, Colors.white.withOpacity(0.95)]),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 10))],
              border: Border.all(color: Colors.grey.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                // icon + glow
                Container(
                  width: circleSmall,
                  height: circleSmall,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [const Color(0xFFE9FFF6), const Color(0xFFDFF7EF)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.14), blurRadius: 16, spreadRadius: 1)],
                  ),
                  child: Center(child: Icon(Icons.check_circle_outline, size: circleSmall * 0.47, color: const Color(0xFF10B981))),
                ),
                const SizedBox(width: 12),
                // allow text area to shrink properly
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Closed Deals', style: GoogleFonts.sora(fontSize: 13, color: Colors.grey[700])),
                      const SizedBox(height: 6),
                      Text('${value.toInt()}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

      Widget commissionCard() => TweenAnimationBuilder<double>(
        duration: animDur,
        tween: Tween(begin: 0.0, end: commissionEarned),
        builder: (context, value, child) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [const Color(0xFFEEF2FF), Colors.white]),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 10))],
              border: Border.all(color: Colors.grey.withOpacity(0.04)),
            ),
            child: Row(
              children: [
                Container(
                  width: circleSmall,
                  height: circleSmall,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [const Color(0xFFEFF6FF), const Color(0xFFE7F0FF)]),
                    boxShadow: [BoxShadow(color: const Color(0xFF4154F1).withOpacity(0.12), blurRadius: 12)],
                  ),
                  child: Center(child: Icon(Icons.monetization_on, size: circleSmall * 0.48, color: const Color(0xFF4154F1))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Commission Earned', style: GoogleFonts.sora(fontSize: 13, color: Colors.grey[700])),
                    const SizedBox(height: 6),
                    Text(formatCurrency(value, decimalDigits: 0), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ],
            ),
          );
        },
      );

      Widget topMetrics;
      if (isNarrow) {
        topMetrics = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            closedDealsCard(),
            const SizedBox(height: 12),
            commissionCard(),
          ],
        );
      } else {
        topMetrics = Row(
          children: [
            Expanded(child: closedDealsCard()),
            const SizedBox(width: 12),
            Expanded(child: commissionCard()),
          ],
        );
      }

      // large card (Yearly target + breakdown)
      Widget largeCard = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) {
          return Transform.scale(scale: 0.98 + 0.02 * scale, child: Opacity(opacity: scale, child: child));
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: [Colors.white, Colors.white]),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 12))],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // stacked: big circular then breakdown below
                    Text('Yearly Target Achievement', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Row(children: [
                      SizedBox(
                        width: circleBig,
                        height: circleBig,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: yearlyTargetAchievement != null ? (yearlyTargetAchievement / 100.0).clamp(0.0, 1.0) : 0.0),
                          duration: const Duration(milliseconds: 900),
                          builder: (context, v, _) {
                            final displayPct = yearlyTargetAchievement != null ? yearlyTargetAchievement.toStringAsFixed(0) : '—';
                            return Stack(alignment: Alignment.center, children: [
                              SizedBox(
                                width: circleBig,
                                height: circleBig,
                                child: CircularProgressIndicator(
                                  value: v,
                                  strokeWidth: 10,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF10B981)),
                                ),
                              ),
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(yearlyTargetAchievement != null ? '$displayPct%' : '—', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text(yearlyTargetAchievement != null ? 'of target' : 'No target', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[600])),
                              ]),
                            ]);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // compact description for narrow screens
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Progress toward annual sales target', style: GoogleFonts.sora(fontSize: 13, color: Colors.grey[700])),
                          const SizedBox(height: 12),
                          Wrap(spacing: 10, runSpacing: 8, children: [
                            _smallStatBox(title: 'Target Achievement', value: yearlyTargetAchievement != null ? '${yearlyTargetAchievement.toStringAsFixed(0)}%' : '—'),
                            _smallStatBox(title: 'Commission Rate', value: '${commissionRate.toStringAsFixed(1)}%'),
                          ]),
                          const SizedBox(height: 12),
                          Text('Legend', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 6),
                          Row(children: [
                            _legendDot(color: const Color(0xFF10B981), label: 'Achieved'),
                            const SizedBox(width: 8),
                            _legendDot(color: Colors.grey.shade300, label: 'Remaining'),
                          ]),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Divider(),
                    const SizedBox(height: 12),
                    Text('Commission Breakdown', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _animatedMetricRow(label: 'Total Earned', value: formatCurrency(commissionEarned, decimalDigits: 0), delay: delayShort),
                    const SizedBox(height: 10),
                    _animatedMetricRow(label: 'Commission Rate', value: '${commissionRate.toStringAsFixed(1)}%'),
                    const SizedBox(height: 10),
                    _animatedMetricRow(label: 'Total Closed Deals', value: '$closedDeals'),
                    const SizedBox(height: 18),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Yearly Target Achievement', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Row(children: [
                          SizedBox(
                            width: circleBig,
                            height: circleBig,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: yearlyTargetAchievement != null ? (yearlyTargetAchievement / 100.0).clamp(0.0, 1.0) : 0.0),
                              duration: const Duration(milliseconds: 900),
                              builder: (context, v, _) {
                                final displayPct = yearlyTargetAchievement != null ? yearlyTargetAchievement.toStringAsFixed(0) : '—';
                                return Stack(alignment: Alignment.center, children: [
                                  SizedBox(
                                    width: circleBig,
                                    height: circleBig,
                                    child: CircularProgressIndicator(
                                      value: v,
                                      strokeWidth: 10,
                                      backgroundColor: Colors.grey.shade200,
                                      valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF10B981)),
                                    ),
                                  ),
                                  Column(mainAxisSize: MainAxisSize.min, children: [
                                    Text(yearlyTargetAchievement != null ? '$displayPct%' : '—', style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    Text(yearlyTargetAchievement != null ? 'of target' : 'No target', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[600])),
                                  ]),
                                ]);
                              },
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Progress toward annual sales target', style: GoogleFonts.sora(fontSize: 13, color: Colors.grey[700])),
                              const SizedBox(height: 12),
                              Row(children: [
                                _smallStatBox(title: 'Target Achievement', value: yearlyTargetAchievement != null ? '${yearlyTargetAchievement.toStringAsFixed(0)}%' : '—'),
                                const SizedBox(width: 10),
                                _smallStatBox(title: 'Commission Rate', value: '${commissionRate.toStringAsFixed(1)}%'),
                              ]),
                              const SizedBox(height: 12),
                              Text('Legend', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[600])),
                              const SizedBox(height: 6),
                              Row(children: [
                                _legendDot(color: const Color(0xFF10B981), label: 'Achieved'),
                                const SizedBox(width: 8),
                                _legendDot(color: Colors.grey.shade300, label: 'Remaining'),
                              ]),
                            ]),
                          ),
                        ]),
                      ]),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 4,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Commission Breakdown', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _animatedMetricRow(label: 'Total Earned', value: formatCurrency(commissionEarned, decimalDigits: 0), delay: delayShort),
                        const SizedBox(height: 10),
                        _animatedMetricRow(label: 'Commission Rate', value: '${commissionRate.toStringAsFixed(1)}%'),
                        const SizedBox(height: 10),
                        _animatedMetricRow(label: 'Total Closed Deals', value: '$closedDeals'),
                        const SizedBox(height: 18),
                      ]),
                    ),
                  ],
                ),
        ),
      );

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title + subtle subtitle
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(child: Text('Your Performance', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            const Spacer(),
            // small last-updated chip
            Chip(
              label: Text('$currentYear', style: GoogleFonts.sora(fontSize: 12, color: Colors.white)),
              backgroundColor: const Color(0xFF2DD4BF),
              visualDensity: VisualDensity.compact,
            )
          ]),
          const SizedBox(height: 18),
          topMetrics,
          const SizedBox(height: 18),
          largeCard,
        ]),
      );
    });
  }

  // helper widgets used by the design above
  Widget _smallStatBox({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.sora(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _legendDot({required Color color, required String label}) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[700])),
    ]);
  }

  Widget _animatedMetricRow({required String label, required String value, Duration delay = Duration.zero}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[700])),
            Text(value, style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w800)),
          ])),
        );
      },
    );
  }

  // ---------------- Top performers Tab ----------------
  Widget _topPerformersTab() {
    if (_profileData.isEmpty) {
      return FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) return _buildShimmerLoader();
          if (s.hasError) return Center(child: Text('Error: ${s.error}'));
          _profileData = Map<String, dynamic>.from(s.data!);
          return _topPerformersContent(_profileData);
        },
      );
    } else {
      return _topPerformersContent(_profileData);
    }
  }

  Widget _topPerformersContent(Map<String, dynamic> profile) {
    final top3 = (profile['top3'] as List<dynamic>?) ?? [];
    final userEntry = (profile['user_entry'] as Map<String, dynamic>?) ?? {};
    final currentYear = profile['current_year'] ?? DateTime.now().year;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Top Performers', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.bold)),
          Chip(label: Text('$currentYear'), backgroundColor: Colors.green, labelStyle: TextStyle(color: Colors.white)),
        ]),
        const SizedBox(height: 16),
        Text('Leaderboard', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Column(children: [
          for (var item in top3) _buildLeaderboardItem(Map<String, dynamic>.from(item)),
          if (userEntry.isNotEmpty) ...[
            const Divider(),
            _buildLeaderboardItem(Map<String, dynamic>.from(userEntry), isCurrentUser: true),
          ],
        ]),
      ]),
    );
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> item, {bool isCurrentUser = false}) {
    final rank = _toInt(item['rank']);
    final marketer = (item['marketer'] is Map) ? Map<String, dynamic>.from(item['marketer']) : <String, dynamic>{};
    final hasTarget = item['has_target'] ?? false;
    final diffPct = _toDouble(item['diff_pct']);
    final category = item['category'] ?? '';

    Color rankColor;
    String rankLabel;

    if (rank == 1) {
      rankColor = Colors.amber;
      rankLabel = 'Gold';
    } else if (rank == 2) {
      rankColor = Colors.grey;
      rankLabel = 'Silver';
    } else if (rank == 3) {
      rankColor = Colors.brown;
      rankLabel = 'Bronze';
    } else {
      rankColor = Colors.blue;
      rankLabel = 'You';
    }

    // display rank (avoid showing 0)
    final displayRank = rank > 0 ? '$rank' : '-';

    // target text: API returns absolute diff_pct; we prefix "+" for display like the HTML.
    final targetText = hasTarget ? '+${diffPct.toStringAsFixed(0)}% $category' : 'Target is yet to be set';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCurrentUser ? Colors.blue : Colors.transparent, width: 1),
      ),
      child: Row(children: [
        Container(width: 40, alignment: Alignment.center, child: Text(displayRank, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(width: 16),
        Stack(children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: marketer['profile_image'] != null
                ? NetworkImage(marketer['profile_image'])
                : AssetImage('assets/avater.webp') as ImageProvider,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: rankColor, borderRadius: BorderRadius.circular(12)),
              child: Text(rankLabel, style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
        ]),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(marketer['full_name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(targetText, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ])),
        // show Top N% if rank available
        Text(rank > 0 ? 'Top $rank%' : '', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
      ]),
    );
  }

  // ---------------- Edit Profile Tab ----------------
  Widget _editProfileTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return _buildShimmerLoader();
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

        final profile = snapshot.data!;
        // ensure controller text (prefill done in _loadProfile but double-check)
        _companyController.text = profile['company'] ?? _companyController.text;
        _jobController.text = profile['job'] ?? _jobController.text;
        _fullNameController.text = profile['full_name'] ?? _fullNameController.text;
        _aboutController.text = profile['about'] ?? _aboutController.text;
        _countryController.text = profile['country'] ?? _countryController.text;
        _addressController.text = profile['address'] ?? _addressController.text;
        _phoneController.text = profile['phone'] ?? _phoneController.text;
        _emailController.text = profile['email'] ?? _emailController.text;

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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                child: Row(children: [
                  Stack(alignment: Alignment.bottomRight, children: [
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
                  ]),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_fullNameController.text.isNotEmpty ? _fullNameController.text : 'Your name', style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      if (_jobController.text.isNotEmpty)
                        Chip(backgroundColor: Colors.grey.shade50, label: Text(_jobController.text, style: GoogleFonts.sora(fontSize: 12, color: Colors.grey.shade800))),
                      if (_companyController.text.isNotEmpty)
                        Chip(backgroundColor: Colors.grey.shade50, label: Text(_companyController.text, style: GoogleFonts.sora(fontSize: 12, color: Colors.grey.shade800))),
                      Chip(backgroundColor: Colors.grey.shade50, label: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.location_on, size: 14, color: Colors.grey), const SizedBox(width: 6), Text(_countryController.text.isNotEmpty ? _countryController.text : 'Country', style: GoogleFonts.sora(fontSize: 12))])),
                    ]),
                    const SizedBox(height: 8),
                    Text(_aboutController.text.isNotEmpty ? _aboutController.text : 'A short friendly bio will appear here.', style: GoogleFonts.sora(fontSize: 13, color: Colors.grey.shade700), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ])),
                ]),
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('About Me', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _input(controller: _aboutController, label: 'Your Bio', icon: Icons.edit, enabled: true, maxLines: 5, hint: 'e.g. I build beautiful apps and love clean UI...'),
                    const SizedBox(height: 14),
                    LayoutBuilder(builder: (ctx, constraints) {
                      final twoCol = constraints.maxWidth >= 680;
                      if (twoCol) {
                        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: Column(children: [
                            _input(controller: _fullNameController, label: 'Full Name', icon: Icons.person, enabled: false),
                            const SizedBox(height: 12),
                            _input(controller: _companyController, label: 'Company', icon: Icons.business),
                            const SizedBox(height: 12),
                            _input(controller: _countryController, label: 'Country', icon: Icons.flag),
                          ])),
                          const SizedBox(width: 12),
                          Expanded(child: Column(children: [
                            _input(controller: _emailController, label: 'Email', icon: Icons.email, enabled: false, keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 12),
                            _input(controller: _jobController, label: 'Job Title', icon: Icons.work),
                            const SizedBox(height: 12),
                            _input(controller: _phoneController, label: 'Phone', icon: Icons.phone, enabled: false, keyboardType: TextInputType.phone),
                          ])),
                        ]);
                      } else {
                        return Column(children: [
                          _input(controller: _fullNameController, label: 'Full Name', icon: Icons.person, enabled: false),
                          const SizedBox(height: 12),
                          _input(controller: _emailController, label: 'Email', icon: Icons.email, enabled: false, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 12),
                          _input(controller: _companyController, label: 'Company', icon: Icons.business),
                          const SizedBox(height: 12),
                          _input(controller: _jobController, label: 'Job Title', icon: Icons.work),
                          const SizedBox(height: 12),
                          _input(controller: _phoneController, label: 'Phone', icon: Icons.phone, enabled: false, keyboardType: TextInputType.phone),
                        ]);
                      }
                    }),
                    const SizedBox(height: 14),
                    _input(controller: _addressController, label: 'Address', icon: Icons.location_on, enabled: false),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitProfileUpdate,
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
                            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.save, color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text('Save Changes', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        );
      },
    );
  }

  // ---------------- Password Tab ----------------
  Widget _passwordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _passwordFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🔒 Change Password', style: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF1A1D2E))),
          const SizedBox(height: 6),
          Text('Keep your account secure by choosing a strong password.', style: GoogleFonts.sora(fontSize: 14, color: Colors.grey[600], height: 1.4)),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              _buildPasswordField(
                controller: _currentPasswordController,
                label: 'Current Password',
                icon: Icons.lock,
                isVisible: _currentVisible,
                toggleVisibility: () => setState(() => _currentVisible = !_currentVisible),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter your current password';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'New Password',
                icon: Icons.lock_outline,
                isVisible: _newVisible,
                toggleVisibility: () => setState(() => _newVisible = !_newVisible),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a new password';
                  if (value.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                icon: Icons.lock_reset,
                isVisible: _confirmVisible,
                toggleVisibility: () => setState(() => _confirmVisible = !_confirmVisible),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please confirm your new password';
                  if (value != _newPasswordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ]),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _submitPasswordChange,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4154F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 4),
              child: Text('Change Password', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
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
        suffixIcon: IconButton(icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey), onPressed: toggleVisibility),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: validator,
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final avatarUrl = profile['profile_image'] as String?;
    final performance = (profile['performance'] as Map<String, dynamic>?) ?? {};
    final userEntry = (profile['user_entry'] as Map<String, dynamic>?) ?? {};
    final currentYear = profile['current_year'] ?? DateTime.now().year;

    final commissionRate = _toDouble(performance['commission_rate']);
    final closedDeals = _toInt(performance['closed_deals']);
    final commissionEarned = _toDouble(performance['commission_earned']);

    final hasTarget = userEntry['has_target'] ?? false;
    final diffPct = _toDouble(userEntry['diff_pct']);
    final userCategory = userEntry['category'] ?? '';
    final userRank = _toInt(userEntry['rank']);

    final propertiesCount = _toInt(profile['properties_count']);
    final totalValue = _toDouble(profile['total_value']);

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
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.92),
            ],
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 12)),
            BoxShadow(color: const Color(0xFF4154F1).withOpacity(0.04), blurRadius: 40, offset: const Offset(0, 8)),
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
                child: Column(children: [
                  Row(children: [
                    Hero(
                      tag: 'profile-image',
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: [const Color(0xFF4154F1).withOpacity(0.12), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))],
                        ),
                        child: ClipOval(
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? FadeInImage.assetNetwork(placeholder: 'assets/avater.webp', image: avatarUrl, fit: BoxFit.cover)
                              : Image.asset('assets/avater.webp', fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(profile['full_name'] ?? 'Unnamed Marketer', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                      const SizedBox(height: 6),
                      Text(profile['job'] ?? profile['company'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.sora(fontSize: 13, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      
                    ])),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(color: const Color(0x0C2575FC), borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      // Commission Rate
                      Column(children: [Text('${commissionRate.toStringAsFixed(1)}%', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF2575FC))), const SizedBox(height: 6), Text('Commission', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[700]))]),
                      // Year target
                      Column(children: [if (hasTarget) Text('+${diffPct.toStringAsFixed(0)}% $userCategory', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)) else Text('Target not set', style: GoogleFonts.sora(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[700])), const SizedBox(height: 6), Text('$currentYear Target', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[700]))]),
                      // Closed deals
                      Column(children: [Text('$closedDeals', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF111827))), const SizedBox(height: 6), Text('Deals', style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[700]))]),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]), borderRadius: BorderRadius.circular(20)), child: Text('Gold', style: GoogleFonts.sora(color: Colors.black, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFC0C0C0), Color(0xFFA9A9A9)]), borderRadius: BorderRadius.circular(20)), child: Text('Silver', style: GoogleFonts.sora(color: Colors.black, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFCD7F32), Color(0xFF8B4513)]), borderRadius: BorderRadius.circular(20)), child: Text('Bronze', style: GoogleFonts.sora(color: Colors.white, fontWeight: FontWeight.w600))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 18, offset: const Offset(0, 12))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Contact Information', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(tooltip: 'Message', onPressed: () {}, icon: const Icon(Icons.message_outlined, color: Color(0xFF4154F1))),
              IconButton(tooltip: 'Call', onPressed: () {}, icon: const Icon(Icons.call_outlined, color: Color(0xFF10B981))),
            ]),
            const SizedBox(height: 12),
            _buildContactItem(icon: Icons.email_outlined, label: 'Email', value: email, onTap: () {
              Clipboard.setData(ClipboardData(text: email));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied to clipboard')));
            }),
            _buildContactItem(icon: Icons.phone_outlined, label: 'Phone', value: phone, onTap: () {
              Clipboard.setData(ClipboardData(text: phone));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone copied to clipboard')));
            }),
            _buildContactItem(icon: Icons.location_on_outlined, label: 'Address', value: address),
            _buildContactItem(icon: Icons.business_outlined, label: 'Company', value: company),
          ]),
        ),
      ),
    );
  }

  Widget _buildContactItem({required IconData icon, required String label, required String value, GestureTapCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF4154F1).withOpacity(0.06), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: const Color(0xFF4154F1))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[600])), const SizedBox(height: 2), Text(value, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600))])),
          if (onTap != null) Padding(padding: const EdgeInsets.only(left: 8.0), child: Icon(Icons.copy, size: 16, color: Colors.grey[400])),
        ]),
      ),
    );
  }

  Widget _buildProfileDetails(Map<String, dynamic> profile) {
    final about = profile['about'] as String? ?? 'Share something about yourself...';
    final rawDate = profile['date_registered'];
    String dateRegistered = 'Not specified';
    if (rawDate != null) {
      try {
        final dt = DateTime.parse(rawDate.toString());
        dateRegistered = DateFormat.yMMMMd().format(dt);
      } catch (_) {
        dateRegistered = rawDate.toString();
      }
    }

    final country = profile['country']?.toString() ?? '-';
    final fullName = profile['full_name']?.toString() ?? '-';
    final job = profile['job']?.toString() ?? '-';
    final company = profile['company']?.toString() ?? '-';
    final address = profile['address']?.toString() ?? '-';
    final phone = profile['phone']?.toString() ?? '-';
    final email = profile['email']?.toString() ?? '-';

    final bool isLong = about.length > 140;
    final preview = isLong ? '${about.substring(0, 140)}…' : about;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 18, offset: const Offset(0, 12))]),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('About You', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(onPressed: () => _tabController.animateTo(3), icon: const Icon(Icons.edit_outlined, color: Color(0xFF4154F1))),
            ]),
            const SizedBox(height: 8),
            AnimatedCrossFade(firstChild: Text(preview, style: GoogleFonts.sora(fontStyle: FontStyle.italic, color: Colors.grey[700])), secondChild: Text(about, style: GoogleFonts.sora(fontStyle: FontStyle.italic, color: Colors.grey[800])), crossFadeState: isLong ? CrossFadeState.showFirst : CrossFadeState.showSecond, duration: const Duration(milliseconds: 450)),
            if (isLong)
              Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('About You', style: GoogleFonts.sora()), content: Text(about, style: GoogleFonts.sora()), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Close', style: GoogleFonts.sora()))])), child: Text('Read more', style: GoogleFonts.sora(color: const Color(0xFF4154F1))))),

            const SizedBox(height: 12),
            Text('Profile Details', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _buildInfoItem(label: 'Full Name', value: fullName),
              _buildInfoItem(label: 'Company', value: company),
              _buildInfoItem(label: 'Job', value: job),
              _buildInfoItem(label: 'Country', value: country),
              _buildInfoItem(label: 'Address', value: address),
              _buildInfoItem(label: 'Phone', value: phone),
              _buildInfoItem(label: 'Email', value: email),
              _buildInfoItem(label: 'Date Registered', value: dateRegistered),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildInfoItem({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 320),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.06))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.sora(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildShimmerLoader() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(height: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
      const SizedBox(height: 14),
      Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Row(children: [Expanded(child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)))), const SizedBox(width: 12), Expanded(child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))))])),
      const SizedBox(height: 14),
      Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(height: 220, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
    ]);
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
