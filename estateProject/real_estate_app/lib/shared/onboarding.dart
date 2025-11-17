import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';

class DynamicLandingPage extends StatefulWidget {
  const DynamicLandingPage({Key? key}) : super(key: key);

  @override
  State<DynamicLandingPage> createState() => _DynamicLandingPageState();
}

enum SiteTheme { Default, Independence, Christmas, Anniversary, Rainy }

class _DynamicLandingPageState extends State<DynamicLandingPage>
    with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  double _topOverlayOpacity = 0.0;
  double _heroHeight = 0.0;

  // add with other state fields
  bool _isUpdatesPaused = false;
  Timer? _updatesAutoPlayTimer;
  final ScrollController _updatesScrollController = ScrollController();

  late AnimationController _glowController;
  late AnimationController _idleRotationController;
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  late AnimationController _sparkleController;

  void _startUpdatesAutoPlay() {
    _updatesAutoPlayTimer?.cancel();

    _updatesAutoPlayTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isUpdatesPaused || updates.isEmpty) return;

      final currentPage = _updatesPageController.page?.round() ?? 0;
      final nextPage = currentPage + 1;

      if (nextPage < updates.length) {
        _updatesPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      } else {
        _updatesPageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _showAllUpdatesSheet() {
    if (!mounted) return;

    _isUpdatesPaused = true;
    _updatesAutoPlayTimer?.cancel();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.78,
          minChildSize: 0.38,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            final theme = _themeData;
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.12), blurRadius: 18)
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                      width: 56,
                      height: 6,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(6))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(children: [
                      Text("All Updates",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme['primary'] as Color)),
                      const Spacer(),
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("Close")),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 8.0),
                      itemCount: updates.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (c, i) {
                        final it = updates[i];
                        return Material(
                          elevation: 2,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.hardEdge,
                          child: ListTile(
                            onTap: () {
                              // close sheet then open the detail modal
                              Navigator.of(context).pop();
                              Future.delayed(const Duration(milliseconds: 260),
                                  () {
                                _showUpdateDetailsModal(it, i);
                              });
                            },
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: it['image'] ?? '',
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                placeholder: (c, u) => Container(
                                    color: (theme['primary'] as Color)
                                        .withOpacity(0.06)),
                                errorWidget: (c, u, e) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image)),
                              ),
                            ),
                            title: Text(it['title'] ?? '',
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(it['date'] ?? ''),
                            trailing: Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey[600]),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // resume autoplay after sheet is closed
      if (mounted) {
        _isUpdatesPaused = false;
        _startUpdatesAutoPlay();
      }
    });
  }

  Widget _infoChip(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // --- CONFIG ---
  final String _whatsAppNumber = "+2348012345678";
  final String _rosaNumber = "+2348098765432";
  SiteTheme _theme = SiteTheme.Default;

  // Sample stats
  final int homesDelivered = 1200;
  final int estatesDeveloped = 30;
  final int yearsInBusiness = 10;

  // Sample project
  final String projectName = "Victoria Court Phase 2";
  int projectSoldPercent = 70;

  late final AnimationController _heroTextController;
  late final Animation<Offset> _headlineOffset;
  late final Animation<double> _headlineOpacity;
  late final AnimationController _floatingController;

  late final AnimationController _statsPulseController;
  late final PageController _projectPageController;
  late final PageController _updatesPageController;
  late final ConfettiController _confettiController;
  int _currentUpdatePage = 0;

  // Sample events
  final List<Map<String, String>> updates = [
    {
      "title": "Independence Day Promo - 7% Off All Lands",
      "date": "Aug 1",
      "image":
          "https://images.unsplash.com/photo-1528909514045-2fa4ac7a08ba?w=800"
    },
    {
      "title": "CSR: Free Borehole for Ajah Community",
      "date": "Jul 28",
      "image":
          "https://images.unsplash.com/photo-1528909514045-2fa4ac7a08ba?w=800"
    },
    {
      "title": "Client Testimonial - Mr. Okafor's Duplex",
      "date": "Jul 12",
      "image":
          "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800"
    },
  ];

  // Spin wheel
  double _rotation = 0.0;
  bool _isSpinning = false;

  final List<String> _prizes = [
    "1% OFF",
    "3% OFF",
    "5% OFF",
    "Free Site Visit",
    "10% OFF",
    "Special Gift"
  ];

  // Diaspora offers
  final List<Map<String, dynamic>> diasporaOffers = [
    {"title": "USD Payment Plans", "icon": Icons.attach_money},
    {"title": "Virtual Tours", "icon": Icons.video_camera_back},
    {"title": "Int'l Transfer Support", "icon": Icons.currency_exchange},
    {"title": "Home Delivery", "icon": Icons.delivery_dining},
  ];

  @override
  void initState() {
    super.initState();
    _startUpdatesAutoPlay();
    _setThemeFromDate(DateTime.now());

    // HEADER SCROLL FADE
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final topPadding = MediaQuery.of(context).padding.top;
      final screenHeight = MediaQuery.of(context).size.height;
      _heroHeight = (screenHeight * 0.40) + topPadding;
      setState(() {});
    });

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ));

    _spinController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _spinController.addListener(() {
      setState(() {
        _rotation = _spinController.value * 2 * pi;
      });
    });
    _spinController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isSpinning = false;
        final prizeIndex = _getPrizeIndexFromRotation(_rotation);
        final prize = _prizes[prizeIndex];
        _showPrizeDialog(prize);
      }
    });

    _heroTextController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _headlineOffset =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _heroTextController, curve: Curves.easeOutQuad));
    _headlineOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _heroTextController, curve: Curves.easeIn));
    _heroTextController.forward();

    _floatingController =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat();

    _statsPulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);

    _projectPageController = PageController(viewportFraction: 0.84);
    _updatesPageController = PageController(viewportFraction: 0.86);
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 900));

    // SPINNER SECTION
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _idleRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _spinAnimation = Tween<double>(
      begin: 0,
      end: Random().nextDouble() * pi * 8,
    ).animate(CurvedAnimation(
      parent: _spinController,
      curve: Curves.easeOutCubic,
    ));

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    _heroTextController.dispose();
    _floatingController.dispose();
    _statsPulseController.dispose();
    _projectPageController.dispose();
    _updatesPageController.dispose();
    _confettiController.dispose();
    _updatesAutoPlayTimer?.cancel();
    _updatesScrollController.dispose();
    _glowController.dispose();
    _idleRotationController.dispose();
    _sparkleController.dispose();

    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    final topInset = MediaQuery.of(context).padding.top;
    final fadeDistance = (topInset + 24.0).clamp(24.0, 72.0);

    final raw = (offset / fadeDistance).clamp(0.0, 1.0);
    final normalized = Curves.easeIn.transform(raw);

    if ((normalized - _topOverlayOpacity).abs() > 0.01) {
      setState(() => _topOverlayOpacity = normalized);

      if (_topOverlayOpacity > 0.55) {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent),
        );
      } else {
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent),
        );
      }
    }
  }

  LinearGradient _buildTopOverlayGradient(
      Map<String, dynamic> theme, double opacityFactor) {
    final base = theme['gradient'] as LinearGradient?;
    if (base == null) {
      final baseColor = (theme['primary'] as Color?) ?? Colors.black;
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          baseColor.withOpacity(opacityFactor * 0.95),
          baseColor.withOpacity(opacityFactor * 0.85),
        ],
      );
    }
    return LinearGradient(
      begin: base.begin,
      end: base.end,
      stops: base.stops,
      colors: base.colors
          .map(
              (c) => c.withOpacity((c.opacity * opacityFactor).clamp(0.0, 1.0)))
          .toList(),
    );
  }

  void _setThemeFromDate(DateTime date) {
    final month = date.month;
    if (month == 12) {
      _theme = SiteTheme.Christmas;
    } else if (month == 8) {
      _theme = SiteTheme.Independence;
    } else if (month == 7) {
      _theme = SiteTheme.Anniversary;
    } else if (month >= 6 && month <= 9) {
      _theme = SiteTheme.Rainy;
    } else {
      _theme = SiteTheme.Default;
    }
  }

  // Launch helpers
  Future<void> _openWhatsAppNumber(String number, {String message = ""}) async {
    final clean = number.replaceAll('+', '').trim();
    final encodedMessage = Uri.encodeComponent(message);
    final directUri =
        Uri.parse("whatsapp://send?phone=$clean&text=$encodedMessage");
    final webUri = Uri.parse("https://wa.me/$clean?text=$encodedMessage");

    try {
      await launchUrl(directUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnack('Could not place call');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Map<String, dynamic> get _themeData {
    switch (_theme) {
      case SiteTheme.Independence:
        return {
          "primary": Colors.green.shade800,
          "accent": Colors.white,
          "hero":
              // "https://images.unsplash.com/photo-1543235278-56f2f7bb0bde?w=1400",
              "https://images.unsplash.com/photo-1494526585095-c41746248156?w=800&idx=i",
          "bannerText": "Celebrate Independence Day",
          "gradient": LinearGradient(colors: [
            Colors.black.withOpacity(0.35),
            Colors.green.shade900.withOpacity(0.25)
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          "accentGradient": LinearGradient(
              colors: [Colors.greenAccent, Colors.green.shade700]),
        };
      case SiteTheme.Christmas:
        return {
          "primary": Colors.red.shade700,
          "accent": Colors.white,
          "hero":
              "https://images.unsplash.com/photo-1494526585095-c41746248156?w=800&idx=i",
          "bannerText": "Seasonal Gift: 5% Off All Estates",
          "gradient": LinearGradient(colors: [
            Colors.black.withOpacity(0.4),
            Colors.red.shade800.withOpacity(0.25)
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          "accentGradient": LinearGradient(
              colors: [Colors.amber.shade200, Colors.red.shade600]),
        };
      case SiteTheme.Anniversary:
        return {
          "primary": Colors.amber.shade800,
          "accent": Colors.white,
          "hero":
              "https://images.unsplash.com/photo-1494526585095-c41746248156?w=800&idx=i",
          "bannerText": "Celebrate Our Anniversary - Thank You!",
          "gradient": LinearGradient(colors: [
            Colors.black.withOpacity(0.3),
            Colors.amber.shade900.withOpacity(0.15)
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          "accentGradient": LinearGradient(
              colors: [Colors.orangeAccent, Colors.amber.shade700]),
        };
      case SiteTheme.Rainy:
        return {
          "primary": Colors.blueGrey.shade900,
          "accent": Colors.white,
          "hero":
              "https://images.unsplash.com/photo-1494526585095-c41746248156?w=800&idx=i",
          "bannerText": "Monsoon Deals & Secure Homes",
          "gradient": LinearGradient(colors: [
            Colors.black.withOpacity(0.45),
            Colors.blueGrey.shade900.withOpacity(0.15)
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          "accentGradient": LinearGradient(
              colors: [Colors.lightBlueAccent, Colors.blueGrey.shade700]),
        };
      default:
        return {
          "primary": Colors.teal.shade700,
          "accent": Colors.white,
          "hero":
              "https://images.unsplash.com/photo-1494526585095-c41746248156?w=800&idx=i",
          "bannerText": "Welcome to Lior & Eliora Properties",
          "gradient": LinearGradient(colors: [
            Colors.black.withOpacity(0.25),
            Colors.teal.shade700.withOpacity(0.08)
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          "accentGradient":
              LinearGradient(colors: [Colors.cyanAccent, Colors.teal.shade600]),
        };
    }
  }

  int _getPrizeIndexFromRotation(double rotation) {
    final normalized = rotation % (2 * pi);
    final seg = (2 * pi) / _prizes.length;
    final idx = ((_prizes.length - (normalized / seg).floor()) % _prizes.length)
        .floor();
    return idx;
  }

  Future<void> _showPrizeDialog(String prize) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!'),
        content: Text('You won: $prize'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
          TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openWhatsAppNumber(_whatsAppNumber);
              },
              child: const Text('Claim via WhatsApp')),
        ],
      ),
    );
  }

  // Animated register modal: showGeneralDialog with scale & fade
  void _showRegisterAnimatedModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Register',
      transitionDuration: const Duration(milliseconds: 520),
      pageBuilder: (context, animation, secondaryAnimation) {
        // pageBuilder must return a widget; the transitionBuilder will animate it
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              child: _registerDialogContent(),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scale =
            CurvedAnimation(parent: animation, curve: Curves.elasticOut).value;
        return FadeTransition(
          opacity: animation,
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }

  Widget _registerDialogContent() {
    final theme = _themeData;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme['accent'],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme['primary'],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Register with Lior & Eliora',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme['primary']),
              ),
            )
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Hi there, to register into our platform, please call or chat with Rosa to serve you better with the requirements.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                _openWhatsAppNumber(_rosaNumber);
              },
              icon: Icon(FontAwesomeIcons.whatsapp),
              label: const Text('Chat Rosa'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                _callNumber(_rosaNumber);
              },
              icon: const Icon(Icons.call),
              label: const Text('Call Rosa'),
            )
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        )
      ]),
    );
  }

  // Quick theme cycle for demo
  void _cycleTheme() {
    setState(() {
      _theme = SiteTheme.values[(_theme.index + 1) % SiteTheme.values.length];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = _themeData;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
    ));

    // final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.grey.shade50,
      bottomNavigationBar: _buildBottomBar(theme),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openWhatsAppNumber(_whatsAppNumber),
        backgroundColor: Colors.green,
        child: Icon(FontAwesomeIcons.whatsapp, color: Colors.white),
        tooltip: 'Chat on WhatsApp',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,

      // allow content to go under the status bar
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // main scrollable content: attach controller
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildHero(theme)),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildStatsRow()),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildAboutCard()),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildProjectSpotlight()),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildUpdatesSection()),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildSeasonalBanner()),
                SliverToBoxAdapter(child: const SizedBox(height: 12)),
                SliverToBoxAdapter(child: _buildDiasporaSection()),
                SliverToBoxAdapter(child: const SizedBox(height: 30)),
                SliverToBoxAdapter(child: _buildSocialProofGrid(context)),
                SliverToBoxAdapter(child: const SizedBox(height: 40)),
                SliverToBoxAdapter(child: _buildFooter()),
                SliverToBoxAdapter(child: const SizedBox(height: 32)),
              ],
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).padding.top + 2.0,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient:
                        _buildTopOverlayGradient(theme, _topOverlayOpacity),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic> theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (theme['primary'] as Color).withOpacity(0.85),
            (theme['primary'] as Color).withOpacity(0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: (theme['primary'] as Color).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                // Login Button
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        icon: const Icon(Icons.login, size: 22),
                        label: const Text(
                          'Login',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Register Button
                Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, scale, child) => Transform.scale(
                      scale: scale,
                      child: OutlinedButton.icon(
                        onPressed: _showRegisterAnimatedModal,
                        icon: const Icon(Icons.app_registration, size: 22),
                        label: const Text(
                          'Register',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side:
                              BorderSide(color: Colors.white.withOpacity(0.5)),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(Map<String, dynamic> theme) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final Color primary = theme['primary'] as Color;
    final LinearGradient gradient = theme['gradient'] as LinearGradient;
    final LinearGradient accentGradient =
        theme['accentGradient'] as LinearGradient;

    // Optional: use a % of screen height for better variety across devices
    final screenHeight = MediaQuery.of(context).size.height;
    final double heroHeight =
        (screenHeight * 0.40) + topPadding; // ~40% of screen + status bar

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (fills behind the status bar)
          Positioned.fill(
            child: Hero(
              tag: 'site-hero',
              child: Image.network(
                theme['hero'],
                fit: BoxFit.cover,
                // keep placeholder full-size to avoid layout jumps
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(color: primary.withOpacity(0.15));
                },
                errorBuilder: (context, error, stack) {
                  // fallback if image fails
                  return Container(
                      color: primary.withOpacity(0.18),
                      child: Center(
                          child: Icon(Icons.image_not_supported,
                              color: Colors.white24)));
                },
              ),
            ),
          ),

          // Gradient overlay to improve text contrast
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 700),
              decoration: BoxDecoration(gradient: gradient),
            ),
          ),

          // Floating shapes (animated)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                final t = (_floatingController.value ?? 0.0);
                final x1 = sin(2 * pi * t) * 26;
                final y1 = cos(2 * pi * t) * 8;
                final x2 = cos(2 * pi * (t + 0.25)) * 30;
                final y2 = sin(2 * pi * (t + 0.25)) * 10;

                return Stack(
                  children: [
                    Positioned(
                      left: 20 + x1,
                      top: 40 + y1,
                      child: Opacity(
                        opacity: 0.14,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: accentGradient,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8)
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 28 + x2,
                      top: 90 + y2,
                      child: Opacity(
                        opacity: 0.10,
                        child: Transform.rotate(
                          angle: 0.35,
                          child: Container(
                            width: 84,
                            height: 40,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withOpacity(0.06),
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

          // Content area (respect system top + small gap)
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: increase tappable area for icons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Home icon - make sure hit area is comfortable on mobile
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: IconButton(
                        constraints:
                            const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: const EdgeInsets.all(8),
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.home, color: Colors.white),
                        tooltip: 'Home',
                      ),
                    ),

                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10)),
                          child: IconButton(
                            constraints: const BoxConstraints(
                                minWidth: 40, minHeight: 40),
                            padding: const EdgeInsets.all(8),
                            onPressed: _cycleTheme,
                            icon: const Icon(Icons.refresh,
                                color: Colors.white70),
                            tooltip: 'Cycle theme',
                          ),
                        )
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Animated headline + subtitle
                SlideTransition(
                  position: _headlineOffset,
                  child: FadeTransition(
                    opacity: _headlineOpacity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Headline
                        ShaderMask(
                          shaderCallback: (bounds) {
                            return const LinearGradient(
                                    colors: [Colors.white, Colors.white70])
                                .createShader(bounds);
                          },
                          child: Text(
                            theme['bannerText'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Secure, verified properties across Nigeria — promos & events updated regularly.",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Buttons row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showPromoSheet(),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 420),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: accentGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: primary.withOpacity(0.28),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8))
                            ],
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.local_offer, color: Colors.white),
                                SizedBox(width: 8),
                                Text("View Promo",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 140,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white.withOpacity(0.06),
                          border: Border.all(color: Colors.white24)),
                      child: TextButton(
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () => _openWhatsAppNumber(_whatsAppNumber),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.chat, color: Colors.white),
                              SizedBox(width: 6),
                              Text("Chat",
                                  style: TextStyle(color: Colors.white)),
                            ]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Decorative bottom curved fade to next section (use transparent -> scaffold bg)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Theme.of(context).scaffoldBackgroundColor
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final theme = _themeData;
    final primary = theme['primary'] as Color;

    // helper for each stat card
    Widget statCard(
        {required IconData icon,
        required String label,
        required int value,
        required Color color}) {
      return Expanded(
        child: AnimatedBuilder(
          animation: _statsPulseController,
          builder: (context, child) {
            final pulse =
                0.92 + (_statsPulseController.value * 0.16); // 0.92..1.08
            return Transform.scale(
              scale: pulse,
              child: Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.12), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // shimmering icon
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        begin:
                            Alignment(-1 + _statsPulseController.value * 2, 0),
                        end: Alignment(1 - _statsPulseController.value * 2, 0),
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.white70,
                          Colors.white.withOpacity(0.95)
                        ],
                      ).createShader(bounds);
                    },
                    child: Icon(icon, size: 28, color: color),
                  ),
                  const SizedBox(height: 8),
                  // animated numeric counter
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: value),
                    duration: const Duration(milliseconds: 1100),
                    builder: (context, val, child) {
                      return Text(
                        val.toString(),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: primary),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(fontSize: 12, color: Colors.black87)),
                ]),
              ),
            );
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
      child: Row(
        children: [
          statCard(
              icon: Icons.home,
              label: "Homes Delivered",
              value: homesDelivered,
              color: Colors.teal),
          statCard(
              icon: Icons.location_city,
              label: "Estates",
              value: estatesDeveloped,
              color: Colors.indigo),
          statCard(
              icon: Icons.star,
              label: "Years",
              value: yearsInBusiness,
              color: Colors.amber.shade700),
        ],
      ),
    );
  }

  void _showAboutDetailsModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'About Lior & Eliora',
      barrierColor:
          Colors.black.withOpacity(0.25), // slight dim beneath the blur
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (context, animation, secondaryAnimation) {
        // full-screen stack so backdropblur covers the entire UI
        return SafeArea(
          child: GestureDetector(
            onTap: () =>
                Navigator.of(context).maybePop(), // tap outside to close
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                  sigmaX: 6.0, sigmaY: 6.0), // <-- blur the background
              child: Container(
                color: Colors.black.withOpacity(
                    0.12), // subtle dim to improve contrast/readability
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () {}, // absorb taps inside dialog
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 760,
                      maxHeight: MediaQuery.of(context).size.height * 0.86,
                    ),
                    child: Material(
                      color: Colors.white.withOpacity(0.98),
                      elevation: 24,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle + close
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Container(
                                      width: 56,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.close, size: 20),
                                  tooltip: 'Close',
                                )
                              ],
                            ),
                          ),

                          // Content body (scrollable)
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _updatesScrollController,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // avatar / image
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          "https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=800",
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (c, child, progress) {
                                            if (progress == null) return child;
                                            return Container(
                                                width: 84,
                                                height: 84,
                                                color: (_themeData['primary']
                                                        as Color)
                                                    .withOpacity(0.07));
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Title + subtitle
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Lior & Eliora Properties',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: _themeData['primary']
                                                    as Color,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Trusted developers — delivering quality homes across Nigeria',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade800,
                                                  height: 1.25),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  // Big readable paragraph
                                  Text(
                                    'Our Story',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _themeData['primary'] as Color),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'We are a trusted real estate company dedicated to providing quality homes and investment opportunities across Nigeria. Our approach blends verified land sourcing, transparent payments, and after-sale support. We focus on community growth and long-term value for buyers.',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.55,
                                        color: Colors.black87),
                                  ),

                                  const SizedBox(height: 14),

                                  // Key facts row (large, readable chips)
                                  Row(
                                    children: [
                                      _infoChip("${homesDelivered}",
                                          "Homes Delivered"),
                                      const SizedBox(width: 8),
                                      _infoChip(
                                          "${estatesDeveloped}", "Estates"),
                                      const SizedBox(width: 8),
                                      _infoChip("${yearsInBusiness}", "Years"),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  Text(
                                    'Why clients trust us',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: _themeData['primary'] as Color),
                                  ),
                                  const SizedBox(height: 8),

                                  // Bulleted benefits with clearer spacing
                                  Column(
                                    children: const [
                                      _BenefitTile(
                                          icon: Icons.verified,
                                          title:
                                              'Fully verified land documentation'),
                                      _BenefitTile(
                                          icon: Icons.support_agent,
                                          title:
                                              'Dedicated after-sales service'),
                                      _BenefitTile(
                                          icon: Icons.lock,
                                          title:
                                              'Secure & transparent payment process'),
                                    ],
                                  ),

                                  const SizedBox(height: 18),

                                  // CTA row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            HapticFeedback.mediumImpact();
                                            _openWhatsAppNumber(
                                                _whatsAppNumber);
                                          },
                                          icon: const Icon(
                                              Icons.chat_bubble_outline),
                                          label: const Text('Chat Sales'),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            HapticFeedback.selectionClick();
                                            _bookSiteVisit();
                                          },
                                          icon: const Icon(
                                              Icons.calendar_today_outlined),
                                          label: const Text('Book Visit'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 18),
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
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final curved = Curves.easeOut.transform(anim.value);
        return Transform.scale(
          scale: 0.98 + 0.02 * curved,
          child: Opacity(opacity: anim.value, child: child),
        );
      },
    );
  }

  Widget _buildAboutCard() {
    final theme = _themeData;
    final primary = theme['primary'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: GestureDetector(
        onTap: _showAboutDetailsModal,
        child: AnimatedBuilder(
          animation: _floatingController,
          builder: (context, _) {
            final t = _floatingController.value;
            final imgOffsetY = sin(2 * pi * t) * 6; // subtle float
            final imgOffsetX = cos(2 * pi * (t + 0.3)) * 4;

            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                // glass + subtle gradient
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.85),
                    Colors.white.withOpacity(0.98)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 8))
                ],
                border: Border.all(color: primary.withOpacity(0.06)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // backdrop blur for glass morphism
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          // left: animated image card
                          Container(
                            width: 96,
                            height: 86,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                    color: primary.withOpacity(0.12),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8))
                              ],
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Transform.translate(
                                  offset: Offset(imgOffsetX, imgOffsetY),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      "https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=800",
                                      fit: BoxFit.cover,
                                      loadingBuilder:
                                          (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                            color: primary.withOpacity(0.08));
                                      },
                                    ),
                                  ),
                                ),
                                // soft overlay
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.22)
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                // micro-badge
                                Positioned(
                                  left: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: primary.withOpacity(0.92),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: const Text('Trusted',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                )
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // middle: text block
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'About Us',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: primary),
                                        ),
                                      ),
                                      // animated small dots indicating micro-interaction
                                      AnimatedBuilder(
                                        animation: _floatingController,
                                        builder: (context, child) {
                                          final dotScale = 0.9 +
                                              (_floatingController.value *
                                                  0.12);
                                          return Transform.scale(
                                            scale: dotScale,
                                            child: const Icon(
                                                Icons.info_outline,
                                                size: 18,
                                                color: Colors.grey),
                                          );
                                        },
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 700),
                                    builder: (context, v, child) {
                                      return Opacity(
                                        opacity: v,
                                        child: Transform.translate(
                                            offset: Offset(0, (1 - v) * 6),
                                            child: const Text(
                                              "We are a trusted real estate company dedicated to providing quality homes and investment opportunities across Nigeria. Our mission is to make property ownership accessible and affordable.",
                                              style: TextStyle(height: 1.4),
                                            )),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _showAboutDetailsModal,
                                        icon: const Icon(Icons.visibility),
                                        label: const Text('Learn more'),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: primary,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12, horizontal: 14)),
                                      ),
                                      const SizedBox(width: 10),
                                      OutlinedButton.icon(
                                        onPressed: () => _openWhatsAppNumber(
                                            _whatsAppNumber),
                                        icon: const Icon(Icons.chat),
                                        label: const Text('Contact'),
                                      )
                                    ],
                                  )
                                ]),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProjectSpotlight() {
    final theme = _themeData;
    final primary = theme['primary'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("This Month's Focus",
              style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            child: PageView.builder(
              controller: _projectPageController,
              itemCount: 1, // Expandable to multiple projects
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, pageIndex) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        // Project image
                        Positioned.fill(
                          child: Image.network(
                            "https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=1200",
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                  color: primary.withOpacity(0.06));
                            },
                          ),
                        ),

                        // dark overlay gradient for contrast
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.12),
                                  Colors.black.withOpacity(0.48)
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),

                        // content
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // project title row with chip
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(projectName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Row(children: [
                                      const Icon(Icons.location_on,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 6),
                                      const Text('Ajah',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12)),
                                    ]),
                                  )
                                ],
                              ),

                              const SizedBox(height: 8),

                              // animated progress bar + percent bubble
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                    begin: 0, end: projectSoldPercent / 100.0),
                                duration: const Duration(milliseconds: 1100),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, child) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: LinearProgressIndicator(
                                            value: v,
                                            minHeight: 10,
                                            backgroundColor: Colors.white24,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    theme['accentGradient']
                                                        .colors
                                                        .first as Color),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Text(
                                            '${(v * 100).round()}% Sold',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12)),
                                      )
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 10),

                              // CTA row: Book & Brochure
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _bookSiteVisit,
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.directions_walk),
                                          SizedBox(width: 8),
                                          Text('Book a Site Visit'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 140,
                                    child: OutlinedButton(
                                      onPressed: _downloadBrochure,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        backgroundColor:
                                            Colors.white.withOpacity(0.06),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.download),
                                            SizedBox(width: 6),
                                            Text('Download Brochure'),
                                          ]),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesSection() {
    final theme = _themeData;
    final primary = theme['primary'] as Color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Text("Updates & Events",
                  style:
                      TextStyle(fontWeight: FontWeight.bold, color: primary)),
              const SizedBox(width: 8),
              const Spacer(),
              // TextButton(
              //   onPressed: () => _showSnack("Open all updates (implement)"),
              //   child: const Text("See all"),
              // ),
              TextButton(
                onPressed: _showAllUpdatesSheet,
                child: const Text("See all"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // PageView carousel
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _updatesPageController,
            itemCount: updates.length,
            pageSnapping: true,
            onPageChanged: (p) => setState(() => _currentUpdatePage = p),
            itemBuilder: (context, index) {
              final item = updates[index];
              return AnimatedBuilder(
                animation: _floatingController,
                builder: (context, child) {
                  final t = _floatingController.value;
                  final floatY = sin(2 * pi * (t + index * 0.09)) * 6;
                  final scale =
                      0.986 + (cos(2 * pi * (t + index * 0.07)) * 0.014);
                  return Transform.translate(
                    offset: Offset(0, floatY),
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: GestureDetector(
                  onTap: () => _showUpdateDetailsModal(item, index),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0, right: 6.0),
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.hardEdge,
                      child: Stack(
                        children: [
                          // image (top portion)
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.topCenter,
                              heightFactor: 0.64,
                              child: LayoutBuilder(
                                  builder: (context, constraints) {
                                final parallax =
                                    (_floatingController.value - 0.5) *
                                        22 *
                                        (index.isEven ? 1 : -1);
                                return Transform.translate(
                                  offset: Offset(parallax, 0),
                                  child: Hero(
                                    tag: 'update-image-$index',
                                    child: CachedNetworkImage(
                                      imageUrl: item['image'] ?? '',
                                      fit: BoxFit.cover,
                                      width: constraints.maxWidth,
                                      height: constraints.maxHeight,
                                      placeholder: (c, u) => Container(
                                          color: primary.withOpacity(0.06)),
                                      errorWidget: (c, u, e) => Container(
                                          color: Colors.grey.shade200,
                                          child:
                                              const Icon(Icons.broken_image)),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),

                          // gradient overlay
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.56)
                                  ],
                                  stops: const [0.45, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // content (bottom)
                          Positioned(
                            left: 14,
                            right: 14,
                            bottom: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              size: 12, color: Colors.white),
                                          const SizedBox(width: 6),
                                          Text(item['date'] ?? '',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    AnimatedBuilder(
                                      animation: _floatingController,
                                      builder: (context, child) {
                                        final p = 0.9 +
                                            (_floatingController.value * 0.16);
                                        return Transform.scale(
                                          scale: p,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 9, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: theme['accentGradient']
                                                  as LinearGradient,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                    color: (primary)
                                                        .withOpacity(0.18),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 4))
                                              ],
                                            ),
                                            child: const Text("New",
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration:
                                      Duration(milliseconds: 420 + index * 60),
                                  curve: Curves.easeOut,
                                  builder: (context, v, child) {
                                    return Opacity(
                                      opacity: v,
                                      child: Transform.translate(
                                          offset: Offset(0, (1 - v) * 8),
                                          child: child),
                                    );
                                  },
                                  child: Text(
                                    item['title'] ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // bottom fade to blend
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Theme.of(context).scaffoldBackgroundColor
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 10),

        // Dots indicator
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(updates.length, (i) {
              final selected = i == _currentUpdatePage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: selected ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: selected
                      ? (theme['primary'] as Color)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                              color:
                                  (theme['primary'] as Color).withOpacity(0.18),
                              blurRadius: 6,
                              offset: const Offset(0, 3))
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  void _showUpdateDetailsModal(Map<String, String> item, int index) {
    // trigger a small confetti burst
    try {
      _confettiController.play();
    } catch (_) {}

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Update detail',
      barrierColor: Colors.black.withOpacity(0.28),
      transitionDuration: const Duration(milliseconds: 360),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
              child: Container(
                color: Colors.black.withOpacity(0.12),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: GestureDetector(
                  onTap: () {},
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: 820,
                        maxHeight: MediaQuery.of(context).size.height * 0.88),
                    child: Material(
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      color: Colors.white,
                      elevation: 28,
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // hero image
                              Hero(
                                tag: 'update-image-$index',
                                child: CachedNetworkImage(
                                  imageUrl: item['image'] ?? '',
                                  height: 240,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (c, u) => Container(
                                      color: (_themeData['primary'] as Color)
                                          .withOpacity(0.06)),
                                  errorWidget: (c, u, e) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image)),
                                ),
                              ),

                              // body
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(18.0),
                                  child: SingleChildScrollView(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                  child: Text(
                                                      item['title'] ?? '',
                                                      style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight
                                                              .bold))),
                                              const SizedBox(width: 12),
                                              Text(item['date'] ?? '',
                                                  style: const TextStyle(
                                                      color: Colors.black54)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            "Detailed description of this update goes here. Use this area to provide more context, next steps, contact info, and any calls to action. You can paste a longer description here and the section will scroll if needed.",
                                            style: TextStyle(height: 1.5),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _openWhatsAppNumber(
                                                          _whatsAppNumber),
                                                  icon: const Icon(Icons.chat),
                                                  label: const Text("Inquire")),
                                              const SizedBox(width: 12),
                                              OutlinedButton.icon(
                                                  onPressed: () => _showSnack(
                                                      'Saved for later (implement)'),
                                                  icon: const Icon(
                                                      Icons.bookmark),
                                                  label: const Text("Save")),
                                              const SizedBox(width: 12),
                                              TextButton(
                                                  onPressed: () => _showSnack(
                                                      'Share (implement)'),
                                                  child: const Text("Share")),
                                            ],
                                          )
                                        ]),
                                  ),
                                ),
                              )
                            ],
                          ),

                          // top-right close button
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Material(
                              color: Colors.white70,
                              shape: const CircleBorder(),
                              child: IconButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ),

                          // Confetti widget anchored near top center of modal
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment(0.0, -0.6),
                              child: ConfettiWidget(
                                confettiController: _confettiController,
                                blastDirectionality:
                                    BlastDirectionality.explosive,
                                shouldLoop: false,
                                colors: const [
                                  Color(0xFFffd166),
                                  Color(0xFFef476f),
                                  Color(0xFF06d6a0),
                                  Color(0xFF118ab2)
                                ],
                                createParticlePath:
                                    _drawStarPath, // optional custom shape (provided below)
                                emissionFrequency: 0.02,
                                numberOfParticles: 20,
                                gravity: 0.2,
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
          ),
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final curved = Curves.easeOut.transform(anim.value);
        return Transform.scale(
            scale: 0.98 + 0.02 * curved,
            child: Opacity(opacity: anim.value, child: child));
      },
    );
  }

  Widget _buildSeasonalBanner() {
    final primary = _themeData['primary'] as Color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Card(
        elevation: 8,
        shadowColor: primary.withOpacity(0.4),
        color: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (_themeData['bannerText'] as String),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Tap to spin and win seasonal rewards!",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Right: Wheel Button
              GestureDetector(
                onTap: _showWheelModal,
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _idleRotationController,
                        builder: (context, _) {
                          return Transform.rotate(
                            angle: _rotation +
                                (_idleRotationController.value * 0.02),
                            child: CustomPaint(
                              size: const Size(88, 88),
                              painter: _WheelPainter(items: _prizes),
                            ),
                          );
                        },
                      ),
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SHOW MODAL WITH SPINNING WHEEL
  void _showWheelModal() {
    showDialog(
      context: context,
      barrierDismissible: true, // allow tap outside / back button to close
      builder: (dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: StatefulBuilder(
            builder: (ctx, setModalState) {
              // Ensure controllers are stopped when the dialog is popped via back/outside tap
              return WillPopScope(
                onWillPop: () async {
                  try {
                    if (_spinController.isAnimating) _spinController.stop();
                  } catch (_) {}
                  try {
                    _confettiController.stop();
                  } catch (_) {}
                  setModalState(() => _isSpinning = false);
                  return true; // allow pop
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header row with close icon
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  "🎯 Spin the Wheel!",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                splashRadius: 20,
                                onPressed: () {
                                  // cleanup then pop
                                  try {
                                    if (_spinController.isAnimating)
                                      _spinController.stop();
                                  } catch (_) {}
                                  try {
                                    _confettiController.stop();
                                  } catch (_) {}
                                  setModalState(() => _isSpinning = false);
                                  Navigator.of(ctx).pop();
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Wheel
                          AnimatedBuilder(
                            animation: _spinController,
                            builder: (context, _) {
                              return Transform.rotate(
                                angle: _spinAnimation.value,
                                child: CustomPaint(
                                  size: const Size(200, 200),
                                  painter: _WheelPainter(items: _prizes),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          ElevatedButton.icon(
                            onPressed: () {
                              // start spin - pass setModalState so it can toggle the local modal state
                              _startSpinWithConfetti(setModalState);
                            },
                            icon: const Icon(Icons.casino),
                            label: const Text("SPIN NOW"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          )
                        ],
                      ),
                    ),

                    // Confetti Effect
                    ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: const [
                        Colors.red,
                        Colors.blue,
                        Colors.green,
                        Colors.orange
                      ],
                    ),

                    // Sparkles
                    if (_isSpinning) _buildSparklesOverlay(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // SPIN LOGIC
  void _startSpinWithConfetti(StateSetter setModalState) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey =
        "spins_${DateTime.now().toIso8601String().substring(0, 10)}";

    int spins = prefs.getInt(todayKey) ?? 0;
    if (spins >= 3) {
      // If limit reached, try to safely close the modal and show limit popup
      try {
        if (_spinController.isAnimating) _spinController.stop();
      } catch (_) {}
      try {
        _confettiController.stop();
      } catch (_) {}
      setModalState(() => _isSpinning = false);
      Navigator.of(context).pop(); // close modal
      _showLimitReachedPopup();
      return;
    }

    setModalState(() => _isSpinning = true);

    final random = Random();
    final spinsCount = 6 + random.nextInt(3); // 6-8 spins
    final targetIndex = random.nextInt(_prizes.length);
    final prize = _prizes[targetIndex];

    _spinAnimation = Tween<double>(
      begin: 0,
      end: (2 * pi * spinsCount) +
          ((2 * pi / _prizes.length) * targetIndex) +
          pi / _prizes.length,
    ).animate(
        CurvedAnimation(parent: _spinController, curve: Curves.easeOutQuart));

    _spinController.forward(from: 0).then((_) async {
      // Spin finished
      setModalState(() => _isSpinning = false);
      try {
        _confettiController.play();
      } catch (_) {}

      // Save spin count
      await prefs.setInt(todayKey, spins + 1);

      // Close wheel modal before showing win popup
      try {
        if (_spinController.isAnimating) _spinController.stop();
      } catch (_) {}
      try {
        // don't stop confetti immediately so user sees it — we'll stop when winning popup is closed
      } catch (_) {}
      Navigator.of(context).pop();

      // small delay before showing winning popup
      Future.delayed(const Duration(milliseconds: 400), () {
        _showWinningPopup(prize);
      });
    }).catchError((err) {
      // ensure state is reset on error
      try {
        _spinController.stop();
      } catch (_) {}
      try {
        _confettiController.stop();
      } catch (_) {}
      setModalState(() => _isSpinning = false);
    });
  }

  void _showWinningPopup(String prize) {
    showDialog(
      context: context,
      barrierDismissible: true, // allow outside/back to dismiss
      builder: (dialogContext) {
        return WillPopScope(
          onWillPop: () async {
            // cleanup any running confetti when modal closed
            try {
              _confettiController.stop();
            } catch (_) {}
            return true;
          },
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            title: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    "🎉 You Won!",
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _themeData['primary'] as Color),
                  ),
                ),
                Positioned(
                  right: 0,
                  child: IconButton(
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.black54),
                    onPressed: () {
                      try {
                        _confettiController.stop();
                      } catch (_) {}
                      Navigator.of(dialogContext).pop();
                    },
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prize,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        _openWhatsAppWithPrize(prize);
                      },
                      icon: const Icon(FontAwesomeIcons.whatsapp,
                          color: Colors.white),
                      label: const Text("Chat to Claim"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    try {
                      _confettiController.stop();
                    } catch (_) {}
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLimitReachedPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Daily Limit Reached 🚫"),
          content: const Text(
            "You have used your 3 spins for today. Come back tomorrow for more chances to win!",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        );
      },
    );
  }

  Future<void> _openWhatsAppWithPrize(String prize) async {
    final phoneNumber = "2347912345678";
    final text = Uri.encodeComponent(
        "Hello! I just won $prize on the Spin & Win game 🎉");
    final url = "https://wa.me/$phoneNumber?text=$text";

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open WhatsApp")),
      );
    }
  }

  // SPARKLE OVERLAY
  Widget _buildSparklesOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        size: const Size(250, 250),
        painter: SparklePainter(_sparkleController.value),
      ),
    );
  }

  // DIASPORA
  Widget _buildDiasporaSection() {
    final primary = _themeData['primary'] as Color? ?? const Color(0xFF6A5AE0);
    final accent = _themeData['accent'] as Color? ?? const Color(0xFF00C2A8);
    final cardAccent =
        _themeData['cardAccent'] as Color? ?? primary.withOpacity(0.06);

    // Optional theme overrides (provide these keys in _themeData to customize)
    final modalIconStart =
        _themeData['diasporaIconStart'] as Color? ?? accent.withOpacity(0.98);
    final modalIconEnd =
        _themeData['diasporaIconEnd'] as Color? ?? primary.withOpacity(0.95);
    final modalIconSize =
        _themeData['diasporaModalIconSize'] as double? ?? 52.0;
    final tileIconStart = _themeData['diasporaTileIconStart'] as Color? ??
        accent.withOpacity(0.95);
    final tileIconEnd = _themeData['diasporaTileIconEnd'] as Color? ??
        primary.withOpacity(0.80);
    final tileIconSize = _themeData['diasporaTileIconSize'] as double? ?? 56.0;

    // Small helper to truncate text nicely
    String _shorten(String text, int max) {
      final trimmed = text.trim();
      if (trimmed.length <= max) return trimmed;
      return trimmed.substring(0, max - 1).trim() + '…';
    }

    // Helper: get a detailed explanation for a given offer.
    String _explainOffer(Map<String, dynamic> offer) {
      final title = (offer['title'] ?? '').toString().toLowerCase();
      final existing = (offer['detail'] ?? '').toString();
      if (existing.trim().isNotEmpty) return existing;

      if (title.contains('shipping') || title.contains('parcel')) {
        return 'Priority Shipping — We manage end-to-end shipment and customs clearance for parcels sent from abroad. '
            'Your package gets priority handling, door-to-door tracking, insured transit and express delivery to recipients in Nigeria.';
      }
      if (title.contains('remit') ||
          title.contains('remittance') ||
          title.contains('transfer')) {
        return 'Remittance Deals — Send money with reduced fees and faster processing. '
            'We partner with licensed international remittance providers to ensure funds arrive safely and can be credited to bank accounts or collected in cash at designated partners. '
            'Transparent FX and same-day options available for eligible corridors.';
      }
      if (title.contains('savings') || title.contains('investment')) {
        return 'Naira Savings & Investment — Access tailored savings plans that help you convert remittances into naira-denominated savings or short-term fixed returns. '
            'These plans are designed for diaspora customers with clear payout terms and easy nominee access for family members in Nigeria.';
      }
      if (title.contains('family') || title.contains('onboard')) {
        return 'Family Onboarding — We help you register household members for services (utility billing, subscriptions, delivery picks) remotely. '
            'Upload documents securely and we’ll complete verification and setup so your family can access services immediately.';
      }
      if (title.contains('property') ||
          title.contains('estate') ||
          title.contains('management')) {
        return 'Property & Estate Management — From rent collection to tenant support, maintenance coordination and property checks, our property team provides full-service management so you can keep investments productive while overseas.';
      }
      if (title.contains('legal') ||
          title.contains('docs') ||
          title.contains('consult')) {
        return 'Legal & Documentation Support — Assistance with notarisation, document translation, power of attorney setups and guidance on remittance compliance — we help you complete paperwork remotely and liaise with local legal partners.';
      }
      if (title.contains('concierge') || title.contains('support')) {
        return 'Concierge & Personal Assistance — Book appointments, arrange deliveries, top-up services or set up voting/registration assistance — our concierge acts as your local on-ground assistant.';
      }
      if (title.contains('tour') || title.contains('virtual')) {
        return 'Virtual Tours — Experience our properties remotely with high-quality 3D/360 tours or scheduled live walkthroughs. '
            'You can view floorplans, ask questions in real time, and shortlist properties from anywhere in the world.';
      }

      // generic fallback
      return 'Detailed service information will be available here. Contact our support for personalized help and tailored packages for diaspora customers.';
    }

    // Helper: detect virtual-tour offers
    bool _isVirtualOffer(Map<String, dynamic> offer) {
      final title = (offer['title'] ?? '').toString().toLowerCase();
      final detail = (offer['detail'] ?? '').toString().toLowerCase();
      return title.contains('tour') ||
          title.contains('virtual') ||
          detail.contains('tour') ||
          detail.contains('virtual');
    }

    // Replace "Home Delivery" with "Document Delivery" using a correct (case-insensitive) RegExp
    String _normalizeTitle(String rawTitle) {
      if (rawTitle.trim().isEmpty) return rawTitle;
      return rawTitle.replaceAll(
          RegExp(r'home\s*delivery', caseSensitive: false),
          'Document Delivery');
    }

    void _openOffersModal() {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Diaspora offers',
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (ctx, anim1, anim2) => const SizedBox.shrink(),
        transitionBuilder: (ctx, animation, secondaryAnimation, child) {
          final scale =
              Curves.easeOutBack.transform(animation.value.clamp(0.0, 1.0));
          return Stack(
            children: [
              // Backdrop blur + slightly stronger dim so modal text is readable
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                      color: Colors.black.withOpacity(0.22 * animation.value)),
                ),
              ),

              // Centered dialog
              Center(
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: animation.value,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.92,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Theme.of(context).cardColor.withOpacity(0.98),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.16),
                                blurRadius: 22,
                                offset: const Offset(0, 12))
                          ],
                        ),
                        child: Stack(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Modal header (bigger & clearer)
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            modalIconStart,
                                            modalIconEnd
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.08),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4))
                                        ],
                                      ),
                                      child: Icon(Icons.card_travel,
                                          color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Diaspora Services',
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  color: primary)),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Priority shipping, remittance offers, virtual tours and more — services designed for Nigerians abroad.',
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.black54,
                                                height: 1.35),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // Scrollable detailed list
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(context).size.height *
                                              0.62),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: List.generate(
                                          diasporaOffers.length, (i) {
                                        final offer = diasporaOffers[i] ?? {};
                                        final rawTitle =
                                            (offer['title'] ?? '').toString();
                                        final title = _normalizeTitle(rawTitle);
                                        final subtitle =
                                            (offer['subtitle'] ?? '')
                                                .toString();
                                        final explanation =
                                            _explainOffer(offer);
                                        final virtual = _isVirtualOffer(offer);

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12.0),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: modalIconSize,
                                                    height: modalIconSize,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          modalIconStart,
                                                          modalIconEnd
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                    0.06),
                                                            blurRadius: 6,
                                                            offset:
                                                                const Offset(
                                                                    0, 4))
                                                      ],
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                          offer['icon']
                                                                  as IconData? ??
                                                              Icons
                                                                  .local_shipping_outlined,
                                                          color: Colors.white),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                                child: Text(
                                                                    title,
                                                                    style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w800,
                                                                        fontSize:
                                                                            16))),
                                                            if (virtual)
                                                              Container(
                                                                margin:
                                                                    const EdgeInsets
                                                                        .only(
                                                                        left:
                                                                            8),
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        4),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: primary
                                                                      .withOpacity(
                                                                          0.08),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                                child: Text(
                                                                    'Virtual',
                                                                    style: TextStyle(
                                                                        color:
                                                                            primary,
                                                                        fontSize:
                                                                            12,
                                                                        fontWeight:
                                                                            FontWeight.w700)),
                                                              ),
                                                          ],
                                                        ),
                                                        if (subtitle.isNotEmpty)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 6),
                                                            child: Text(
                                                                subtitle,
                                                                style: const TextStyle(
                                                                    color: Colors
                                                                        .black54)),
                                                          ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(explanation,
                                                            style:
                                                                const TextStyle(
                                                                    height: 1.5,
                                                                    fontSize:
                                                                        14)),
                                                        const SizedBox(
                                                            height: 12),

                                                        // ACTIONS: only show for virtual offers (per your request)
                                                        if (virtual)
                                                          Row(
                                                            children: [
                                                              ElevatedButton
                                                                  .icon(
                                                                onPressed:
                                                                    () async {
                                                                  Navigator.of(
                                                                          ctx)
                                                                      .pop();
                                                                  try {
                                                                    await Navigator.of(
                                                                            context)
                                                                        .pushNamed(
                                                                            '/virtual-tour');
                                                                  } catch (_) {
                                                                    ScaffoldMessenger.of(
                                                                            context)
                                                                        .showSnackBar(const SnackBar(
                                                                            content:
                                                                                Text('Opening virtual tour...')));
                                                                  }
                                                                },
                                                                icon: const Icon(
                                                                    Icons
                                                                        .vrpano,
                                                                    color: Colors
                                                                        .white),
                                                                label: const Text(
                                                                    'Tour Now',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .white)),
                                                                style: ElevatedButton
                                                                    .styleFrom(
                                                                  backgroundColor:
                                                                      primary,
                                                                  shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              12)),
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          14,
                                                                      vertical:
                                                                          12),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 12),
                                                              OutlinedButton
                                                                  .icon(
                                                                onPressed: () {
                                                                  Navigator.of(
                                                                          ctx)
                                                                      .pop();
                                                                  _openWhatsAppNumber(
                                                                      _whatsAppNumber);
                                                                },
                                                                icon: const Icon(
                                                                    Icons
                                                                        .chat_bubble_outline),
                                                                label: const Text(
                                                                    'Chat Admin'),
                                                                style: OutlinedButton
                                                                    .styleFrom(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          12),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Divider(height: 26),
                                            ],
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Footer: only Close button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Close')),
                                  ],
                                ),
                              ],
                            ),

                            // Close icon top-right
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                splashRadius: 22,
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.black54),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ],
          );
        },
      );
    }

    // Horizontal animated tile builder - icon colors improved
    Widget _buildTile(Map<String, dynamic> offer, int index) {
      final icon = offer['icon'] as IconData? ?? Icons.local_shipping_outlined;
      final rawTitle = (offer['title'] ?? '').toString();
      final title = _normalizeTitle(rawTitle);
      // small description below the title — prefer subtitle then fall back to truncated explanation
      final descriptionForTile =
          (offer['subtitle'] ?? '').toString().trim().isNotEmpty
              ? (offer['subtitle'] as String)
              : _shorten(_explainOffer(offer), 60);
      final ms = 360 + (index * 70);

      return TweenAnimationBuilder<Offset>(
        tween: Tween(begin: const Offset(18, 0), end: Offset.zero),
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
        builder: (context, offset, child) {
          final progress = 1.0 - (offset.dx.abs() / 18.0);
          return Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: Transform.translate(offset: offset, child: child));
        },
        child: GestureDetector(
          onTap: () {
            // open modal for details instead of only snack
            _openOffersModal();
          },
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Row(
              children: [
                // stronger circular icon background for visibility
                Container(
                  width: tileIconSize,
                  height: tileIconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [tileIconStart, tileIconEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child:
                      Center(child: Icon(icon, color: Colors.white, size: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        // <- small description below the title (one/two lines max)
                        Text(
                          descriptionForTile,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.25),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [cardAccent, Colors.white]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withOpacity(0.04)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 12))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header row
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.flight, color: Colors.blue),
                  const SizedBox(width: 10),
                  Text('Diaspora Corner',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primary)),
                ]),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openOffersModal(),
                icon: Icon(Icons.card_travel, color: primary.withOpacity(0.95)),
                label: Text('View all',
                    style: TextStyle(color: primary.withOpacity(0.95))),
              ),
            ]),

            // Short subtitle directly under the carousel title for clarity
            const SizedBox(height: 8),
            Text('Special services for Nigerians abroad',
                style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 14),

            // Horizontal scroll row of cards with improved icon visibility
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: diasporaOffers.length,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final offer = diasporaOffers[index];
                  return _buildTile(offer, index);
                },
              ),
            ),

            const SizedBox(height: 16),

            // Main CTA: opens the modal with all offers (this is where the modal lives)
            Center(
              child: GestureDetector(
                onTap: _openOffersModal,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [primary, primary.withOpacity(0.86)]),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: primary.withOpacity(0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 8))
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.flight_takeoff, color: Colors.white),
                    const SizedBox(width: 10),
                    const Text('View Diaspora Offers',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSocialProofGrid(BuildContext context) {
    final images = List.generate(
      4,
      (i) =>
          "https://images.unsplash.com/photo-1494526585095-c41746248156?w=800&idx=$i",
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Social Proof & Community",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 12),

          // Grid with animations
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: images.length,
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () {
                  // Optional: open image or community story
                },
                child: Stack(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),

                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),

                    // Caption
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Text(
                        "Community Story ${i + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms, delay: (i * 150).ms).scale(
                    begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Contact Us", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text("NeuraLens Properties Limited"),
        const SizedBox(height: 2),
        const Text("CAC: RC123456789"),
        const SizedBox(height: 2),
        const Text("Address: 12 Victoria Island, Lagos"),
        const SizedBox(height: 12),
        Row(children: [
          ElevatedButton.icon(
              onPressed: () => _openWhatsAppNumber(_whatsAppNumber),
              icon: Icon(FontAwesomeIcons.whatsapp),
              label: const Text("Chat on WhatsApp")),
          const SizedBox(width: 8),
          OutlinedButton.icon(
              onPressed: () => _callNumber(_whatsAppNumber),
              icon: const Icon(Icons.call),
              label: const Text("Call Us"))
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.start, children: [
          _buildSocialIcon(FontAwesomeIcons.facebook, Colors.blue[700]!),
          const SizedBox(width: 12),
          _buildSocialIcon(FontAwesomeIcons.instagram, Colors.pink),
          const SizedBox(width: 12),
          _buildSocialIcon(FontAwesomeIcons.linkedin, Colors.blue[800]!),
          const SizedBox(width: 12),
          _buildSocialIcon(FontAwesomeIcons.youtube, Colors.red),
        ]),
      ]),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // Open your social link - replace with real URLs
        _showSnack('Open social (implement link)');
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  // Placeholder actions
  void _bookSiteVisit() {
    _showSnack('Booking flow goes here');
  }

  void _downloadBrochure() {
    _showSnack('Downloading brochure...');
  }

  void _showPromoSheet() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (context) {
          return SizedBox(
            height: 320,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_themeData['bannerText'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                        "Current promotions and limited-time offers are listed here."),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: () => _openWhatsAppNumber(_whatsAppNumber),
                        child: const Text("Claim Offer via WhatsApp")),
                    const SizedBox(height: 10),
                    ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Close"))
                  ]),
            ),
          );
        });
  }
}

class SparklePainter extends CustomPainter {
  final double animationValue;

  SparklePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final sparklePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    const sparkleCount = 14; // number of sparkles
    final radiusBase = size.width / 2 + 16; // base radius from center

    for (int i = 0; i < sparkleCount; i++) {
      final angle = (2 * pi / sparkleCount) * i + animationValue * 2 * pi;
      final dx = size.width / 2 + radiusBase * cos(angle);
      final dy = size.height / 2 + radiusBase * sin(angle);

      _drawStar(canvas, Offset(dx, dy), 3.5, sparklePaint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    const points = 5;
    for (int i = 0; i < points * 2; i++) {
      final angle = (pi / points) * i;
      final r = (i % 2 == 0) ? size : size / 2.5;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklePainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}

class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _BenefitTile({required this.icon, required this.title, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<String> items;
  _WheelPainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final seg = 2 * pi / items.length;
    final r = min(size.width, size.height) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: r);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < items.length; i++) {
      final start = -pi / 2 + i * seg;
      final paint = Paint()
        ..color =
            Colors.primaries[i % Colors.primaries.length].withOpacity(0.85);
      canvas.drawArc(rect, start, seg, true, paint);
      final angle = start + seg / 2;
      final label = items[i];
      textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(
              fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold));
      textPainter.layout(maxWidth: r * 0.9);
      final offset = Offset(
          center.dx + cos(angle) * r * 0.5 - textPainter.width / 2,
          center.dy + sin(angle) * r * 0.5 - textPainter.height / 2);
      canvas.save();
      canvas.translate(offset.dx + textPainter.width / 2,
          offset.dy + textPainter.height / 2);
      canvas.rotate(angle + pi / 2);
      canvas.translate(-(offset.dx + textPainter.width / 2),
          -(offset.dy + textPainter.height / 2));
      textPainter.paint(canvas, offset);
      canvas.restore();
    }
    final centerPaint = Paint()..color = Colors.black.withOpacity(0.6);
    canvas.drawCircle(center, r * 0.2, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Path _drawStarPath(Size size) {
  // small 5-point star
  const numberOfPoints = 5;
  final path = Path();
  final halfWidth = size.width / 2;
  final externalRadius = halfWidth;
  final internalRadius = halfWidth / 2.5;
  final step = pi / numberOfPoints;
  path.moveTo(size.width, halfWidth);
  for (int i = 0; i < numberOfPoints * 2; i++) {
    final r = i.isEven ? externalRadius : internalRadius;
    final angle = i * step;
    final x = halfWidth + r * cos(angle);
    final y = halfWidth + r * sin(angle);
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  path.close();
  return path;
}
