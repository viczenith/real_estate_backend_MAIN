import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:real_estate_app/client/client_bottom_nav.dart';
import 'package:real_estate_app/shared/app_layout.dart';
import 'package:real_estate_app/shared/app_side.dart';
import 'package:real_estate_app/core/api_service.dart';

class ClientDashboard extends StatefulWidget {
  final String token;
  const ClientDashboard({Key? key, required this.token}) : super(key: key);

  @override
  _ClientDashboardState createState() => _ClientDashboardState();
}

class _ClientDashboardState extends State<ClientDashboard>
    with TickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  String? _clientName;

  Future<void> _fetchClientName() async {
    try {
      // make profile dynamic so runtime type checks are allowed
      final dynamic profile =
          await _api.getClientDetailByToken(token: widget.token);

      if (!mounted) return;

      String? name;

      if (profile is Map<String, dynamic>) {
        // try common name/email keys
        name = (profile['full_name'] ??
                profile['fullName'] ??
                profile['name'] ??
                profile['display_name'] ??
                profile['displayName'] ??
                profile['email'])
            ?.toString();

        // fallback to first + last
        if (name == null || name.trim().isEmpty) {
          final first =
              (profile['first_name'] ?? profile['firstName'])?.toString();
          final last =
              (profile['last_name'] ?? profile['lastName'])?.toString();
          if ((first?.isNotEmpty == true) || (last?.isNotEmpty == true)) {
            name = '${first ?? ''} ${last ?? ''}'.trim();
          }
        }

        // try nested shapes like { user: { ... } } or { client: { ... } }
        if (name == null || name.trim().isEmpty) {
          if (profile['user'] is Map) {
            final u = Map<String, dynamic>.from(profile['user'] as Map);
            name = (u['full_name'] ?? u['name'] ?? u['email'])?.toString();
          } else if (profile['client'] is Map) {
            final c = Map<String, dynamic>.from(profile['client'] as Map);
            name = (c['full_name'] ?? c['name'] ?? c['email'])?.toString();
          }
        }
      } else if (profile is String) {
        // sometimes the API might (unexpectedly) return a plain string
        name = profile;
      }

      final finalName =
          (name != null && name.trim().isNotEmpty) ? name.trim() : null;

      if (!mounted) return;
      setState(() {
        _clientName = finalName;
      });
    } catch (e, st) {
      debugPrint('Failed to fetch client name: $e\n$st');
      // leave _clientName null so the UI falls back to "Client Dashboard"
    }
  }

  Map<String, dynamic> _data = {};

  List<Map<String, dynamic>> _activePromos = [];
  List<Map<String, dynamic>> _latestValue = [];

  // Price explorer controls
  final TextEditingController _priceSearchCtr = TextEditingController();
  String _priceSort = 'newest';
  bool _promoOnly = false;

  late final AnimationController _staggerController;
  late final Animation<double> _staggerAnim;
  late final AnimationController _pulseController;

  // Auto carousel for promotions
  Timer? _promoCarouselTimer;
  final PageController _promoPageController =
      PageController(viewportFraction: 0.92);
  int _currentPromoIndex = 0;

  final NumberFormat _ngnFmt =
      NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _staggerAnim =
        CurvedAnimation(parent: _staggerController, curve: Curves.easeOutCubic);
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    // _fetchDashboard();
    _fetchClientName().whenComplete(() => _fetchDashboard());
  }

  @override
  void dispose() {
    _priceSearchCtr.dispose();
    _staggerController.dispose();
    _pulseController.dispose();
    _promoPageController.dispose();
    _promoCarouselTimer?.cancel();
    super.dispose();
  }

  // Start auto carousel for promotions
  void _startPromoCarousel() {
    _promoCarouselTimer?.cancel();
    _promoCarouselTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_activePromos.isEmpty) return;

      int nextPage = _currentPromoIndex + 1;
      if (nextPage >= _activePromos.length) {
        nextPage = 0;
      }

      if (_promoPageController.hasClients) {
        _promoPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _api.getClientDashboardData(widget.token);
      // expected keys: total_properties, fully_paid_allocations, not_fully_paid_allocations, active_promotions, latest_value
      setState(() {
        _data = resp;
        _activePromos =
            List<Map<String, dynamic>>.from(resp['active_promotions'] ?? []);
        _latestValue =
            List<Map<String, dynamic>>.from(resp['latest_value'] ?? []);
      });
      _staggerController.forward();

      // Start the carousel after data is loaded
      if (_activePromos.isNotEmpty) {
        _startPromoCarousel();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Filter + sort logic similar to Django's JS
  List<Map<String, dynamic>> _filteredPriceCards() {
    final q = _priceSearchCtr.text.trim().toLowerCase();
    List<Map<String, dynamic>> cards = List.from(_latestValue);

    if (_promoOnly) cards = cards.where((c) => c['promo'] != null).toList();
    if (q.isNotEmpty) {
      cards = cards.where((c) {
        final estate = (c['estate_name'] ?? '').toString().toLowerCase();
        final size = (c['plot_unit'] != null && c['plot_unit'] is Map
            ? (c['plot_unit']['size'] ?? '').toString().toLowerCase()
            : '');
        return estate.contains(q) || size.contains(q);
      }).toList();
    }

    int cmpPercent(Map a) => ((a['percent_change'] ?? 0) as num).toInt();
    double curVal(Map a) => (a['current'] ?? 0).toDouble();

    cards.sort((a, b) {
      switch (_priceSort) {
        case 'biggest_up':
          return (b['percent_change'] ?? 0).compareTo(a['percent_change'] ?? 0);
        case 'biggest_down':
          return (a['percent_change'] ?? 0).compareTo(b['percent_change'] ?? 0);
        case 'highest_price':
          return curVal(b).compareTo(curVal(a));
        case 'promo_first':
          final ap =
              (b['promo'] != null ? 1 : 0) - (a['promo'] != null ? 1 : 0);
          if (ap != 0) return ap;
          return (b['percent_change'] ?? 0).compareTo(a['percent_change'] ?? 0);
        case 'newest':
        default:
          final ae = (a['effective'] ?? '').toString();
          final be = (b['effective'] ?? '').toString();
          return be.compareTo(ae);
      }
    });

    return cards;
  }

  String _formatNGN(dynamic v) {
    if (v == null) return '—';
    try {
      final numVal = (v is num) ? v : double.tryParse(v.toString()) ?? 0;
      return _ngnFmt.format(numVal);
    } catch (e) {
      return v.toString();
    }
  }

  bool _isFutureDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();

      // Compare dates only (without time component)
      final effectiveDate = DateTime(date.year, date.month, date.day);
      final today = DateTime(now.year, now.month, now.day);

      // Return true ONLY if effective date is in the future (not today)
      // Today means the effective date has arrived, so it's "since" not "on"
      return effectiveDate.isAfter(today);
    } catch (e) {
      return false;
    }
  }

  String _formatDateDisplay(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _openPromoDetail(Map<String, dynamic> promo) async {
    // push to PromotionDetailPage
    final id = (promo['id'] as num?)?.toInt();
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PromotionDetailPage(token: widget.token, promoId: id)));
  }

  Future<void> _openPriceDetail(int id) async {
    showDialog(
        context: context,
        builder: (_) => PriceDetailDialog(
            api: _api, token: widget.token, priceHistoryId: id));
  }

  Widget _buildTopStats() {
    final total = (_data['total_properties'] ?? 0).toString();
    final fully = (_data['fully_paid_allocations'] ?? 0).toString();
    final notFully = (_data['not_fully_paid_allocations'] ?? 0).toString();

    Widget statCard(String title, String value, IconData icon, Color color) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 20),
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 260;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.9),
                          color.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: narrow ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 800),
                          tween: Tween(
                              begin: 0, end: double.tryParse(value) ?? 0.0),
                          builder: (context, val, _) {
                            return Text(
                              val.toStringAsFixed(0),
                              style: TextStyle(
                                fontSize: narrow ? 20 : 26,
                                fontWeight: FontWeight.w900,
                                color: color,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;
        final cardWidth = (math.min(400, constraints.maxWidth / 3 - 16)).toDouble();

        final cards = [
          statCard('My Properties Purchased', total, Icons.home_rounded, Colors.indigo),
          statCard('Fully Paid & Allocated', fully, Icons.verified_rounded, Colors.teal),
          statCard('Not Fully Paid', notFully, Icons.warning_amber_rounded, Colors.orange),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: isWide
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: cards
                            .map((c) => SizedBox(width: cardWidth, child: c))
                            .toList(),
                      )
                    : Column(
                        children: [
                          ...cards.expand((c) => [c, const SizedBox(height: 12)]).toList()
                            ..removeLast(),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPromotionsCarousel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // --- small helpers kept inside the widget (no external changes) ---
    Widget _decorCircle(double size, double opacity) {
      // Use small sizes and OverflowBox so decorative shapes never trigger layout overflow
      return OverflowBox(
        maxWidth: size,
        maxHeight: size,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary.withOpacity(opacity),
          ),
        ),
      );
    }

    Widget _discountBadge(String discount, bool compact) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 6 : 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFff6b6b), Color(0xFFffa500)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFFff6b6b).withOpacity(0.22), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('-$discount%', style: TextStyle(fontSize: compact ? 14 : 16, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 2),
            Text('OFF', style: TextStyle(fontSize: compact ? 9 : 10, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      );
    }

    Widget _emptyState(double maxWidth) {
      final compact = maxWidth < 600;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 20, vertical: 8),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(offset: Offset(0, 28 * (1 - v)), child: child),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: BoxConstraints(maxWidth: math.min(920, maxWidth - 24)),
              padding: EdgeInsets.all(compact ? 20 : 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark ? [const Color(0xFF0b1220), const Color(0xFF0f1724)] : [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade200, width: 1.0),
                boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.45) : Colors.grey.withOpacity(0.08), blurRadius: 22, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.96, end: 1.04),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeInOut,
                    builder: (context, val, child) => Transform.scale(scale: val, child: child),
                    child: Container(
                      width: compact ? 72 : 88,
                      height: compact ? 72 : 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.7)]),
                        boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.22), blurRadius: 18)],
                      ),
                      child: Icon(Icons.local_offer_rounded, color: Colors.white, size: compact ? 36 : 44),
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 18),
                  Text('No Active Promotions',
                      style: TextStyle(fontSize: compact ? 18 : 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.grey.shade900)),
                  SizedBox(height: 8),
                  Text(
                    'Check back soon for exclusive offers — or browse available estates now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: compact ? 13 : 15, color: isDark ? Colors.white70 : Colors.grey.shade600, height: 1.45),
                  ),
                  SizedBox(height: compact ? 12 : 18),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EstatesListPage(token: widget.token))),
                        icon: const Icon(Icons.home_work_rounded, size: 18),
                        label: const Text('Browse Estates'),
                        style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PromotionsListPage(token: widget.token, filter: 'past'))),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('Past Promos'),
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
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

    // ---------- empty case ----------
    if (_activePromos.isEmpty) {
      return LayoutBuilder(builder: (context, constraints) => _emptyState(constraints.maxWidth));
    }

    // ---------- carousel case ----------
    return LayoutBuilder(builder: (context, constraints) {
      final screenWidth = constraints.maxWidth;
      final isSmall = screenWidth < 600;
      final isMedium = screenWidth >= 600 && screenWidth < 1000;

      // tuned heights to avoid overflow while keeping a bold look
      final cardHeight = isSmall ? (screenWidth / 1.6) : (isMedium ? 380.0 : 460.0);

      // ClipRect + ClipRRect everywhere to prevent any overflow pixels
      return Column(
        children: [
          ClipRect(
            child: SizedBox(
              height: cardHeight,
              child: PageView.builder(
                controller: _promoPageController,
                onPageChanged: (index) => setState(() => _currentPromoIndex = index),
                itemCount: _activePromos.length,
                itemBuilder: (ctx, i) {
                  final promo = _activePromos[i];
                  final estates = List.from(promo['estates'] ?? []);
                  final discount = (promo['discount'] ?? 0).toString();
                  final promoName = promo['name'] ?? 'Promotion';
                  final description = promo['description'] ?? '';
                  final endDate = promo['end'] ?? '';

                  // Use AnimatedBuilder reading the controller for subtle parallax/scale
                  return AnimatedBuilder(
                    animation: _promoPageController,
                    builder: (context, child) {
                      double page = 0;
                      try {
                        page = _promoPageController.hasClients ? (_promoPageController.page ?? _currentPromoIndex.toDouble()) : _currentPromoIndex.toDouble();
                      } catch (_) {
                        page = _currentPromoIndex.toDouble();
                      }
                      final delta = (i - page);
                      final absDelta = delta.abs().clamp(0.0, 1.0);
                      final scale = 1 - (absDelta * 0.06);
                      final translateY = 14 * absDelta;
                      final rotateY = delta * 0.02;

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..translate(0.0, translateY)
                          ..scale(scale, scale)
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(rotateY),
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16, vertical: isSmall ? 8 : 10),
                      child: GestureDetector(
                        onTap: () => _openPromoDetail(promo),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: cardHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark ? [const Color(0xFF0b1220), const Color(0xFF0f1724)] : [Colors.white, Colors.grey.shade50],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade200, width: 1),
                              boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.5) : Colors.grey.withOpacity(0.12), blurRadius: 28, offset: const Offset(0, 12))],
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Decorative shapes placed inside OverflowBox so they don't cause overflow errors
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8, top: 4),
                                      child: _decorCircle(140, 0.035),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                                      child: _decorCircle(100, 0.028),
                                    ),
                                  ),
                                ),

                                // soft shimmer overlay (low opacity, animation via Tween so no repaint overflow)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    ignoring: true,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: -1.0, end: 2.0),
                                      duration: const Duration(seconds: 4),
                                      builder: (context, val, child) {
                                        return FractionallySizedBox(
                                          widthFactor: 1.5,
                                          alignment: Alignment(-val, 0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  Theme.of(context).colorScheme.primary.withOpacity(0.04),
                                                  Colors.transparent
                                                ],
                                                stops: const [0.0, 0.5, 1.0],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                                // Card content (kept inside padding to prevent overflow)
                                Padding(
                                  padding: EdgeInsets.all(isSmall ? 14 : 18),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: isSmall ? 52 : 64,
                                            height: isSmall ? 52 : 64,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.7)]),
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.26), blurRadius: 16, offset: const Offset(0, 8))],
                                            ),
                                            child: Icon(Icons.local_offer_rounded, color: Colors.white, size: isSmall ? 26 : 30),
                                          ),
                                          SizedBox(width: isSmall ? 10 : 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  promoName,
                                                  style: TextStyle(fontSize: isSmall ? 16 : 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.grey.shade900, height: 1.08),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if ((description ?? '').isNotEmpty) ...[
                                                  SizedBox(height: 6),
                                                  Text(
                                                    description,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(fontSize: isSmall ? 12 : 13, color: isDark ? Colors.white70 : Colors.grey.shade600),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _discountBadge(discount, isSmall),
                                        ],
                                      ),

                                      SizedBox(height: isSmall ? 10 : 14),

                                      if (estates.isNotEmpty)
                                        ConstrainedBox(
                                          constraints: BoxConstraints(maxHeight: isSmall ? 36 : 44),
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: estates.length > 4 ? 5 : estates.length,
                                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                                            itemBuilder: (context, idx) {
                                              if (idx == 4 && estates.length > 4) {
                                                return Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200)),
                                                  child: Text('+${estates.length - 4} more', style: TextStyle(fontWeight: FontWeight.w700, fontSize: isSmall ? 11 : 13)),
                                                );
                                              }
                                              final estate = estates[idx];
                                              return Container(
                                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.14))),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.home, size: isSmall ? 12 : 14, color: Theme.of(context).colorScheme.primary),
                                                    const SizedBox(width: 6),
                                                    ConstrainedBox(
                                                      constraints: BoxConstraints(maxWidth: isSmall ? 80 : 140),
                                                      child: Text(estate['name'] ?? '', style: TextStyle(fontSize: isSmall ? 11 : 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                      const Spacer(),

                                      Row(
                                        children: [
                                          if ((endDate ?? '').isNotEmpty)
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(color: isDark ? Colors.red.shade900.withOpacity(0.12) : Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.access_time_rounded, size: isSmall ? 12 : 14, color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                                                  const SizedBox(width: 8),
                                                  Text('Ends $endDate', style: TextStyle(fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.w700, color: isDark ? Colors.red.shade300 : Colors.red.shade700)),
                                                ],
                                              ),
                                            ),
                                          const Spacer(),
                                          ElevatedButton.icon(
                                            onPressed: () => _openPromoDetail(promo),
                                            icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
                                            label: const Text('View Promo'),
                                            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (_activePromos.length > 1)
            SizedBox(
              height: 28,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    _activePromos.length,
                    (idx) {
                      final active = idx == _currentPromoIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: active ? 32 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: active ? LinearGradient(colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withOpacity(0.7)]) : null,
                          color: active ? null : (isDark ? Colors.white.withOpacity(0.18) : Colors.grey.shade300),
                          boxShadow: active ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 2))] : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          const SizedBox(height: 6),
        ],
      );
    });
  }


  DateTime? _parseDateDynamic(dynamic v) {
    if (v == null) return null;
    try {
      if (v is DateTime) return v;
      if (v is int) {
        if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
        return DateTime.fromMillisecondsSinceEpoch(v * 1000);
      }
      final s = v.toString();
      return DateTime.parse(s);
    } catch (e) {
      try {
        final s = v.toString().split('T').first;
        final parts = s.split(RegExp(r'[-/]'));
        if (parts.length >= 3) {
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final d = int.parse(parts[2]);
          return DateTime(y, m, d);
        }
      } catch (_) {}
    }
    return null;
  }

  bool isCurrentUpdate(Map<String, dynamic> u) {
    final effRaw = u['effective'];
    final effDt = _parseDateDynamic(effRaw);
    if (effDt == null) return false;
    final now = DateTime.now();
    final effDate = DateTime(effDt.year, effDt.month, effDt.day);
    final today = DateTime(now.year, now.month, now.day);
    return !effDate.isAfter(today);
  }

  List<Map<String, dynamic>> pickLatestPerPlotUnit(
      List<Map<String, dynamic>> updates) {
    final Map<String, List<Map<String, dynamic>>> buckets = {};
    for (final u in updates) {
      dynamic pu = u['plot_unit'];
      String key;
      if (pu == null) {
        final est = (u['estate_name'] ?? 'estate').toString();
        final size = (u['plot_unit'] is Map)
            ? (u['plot_unit']['size'] ?? '')
            : (u['size'] ?? '');
        key = '$est|$size';
      } else if (pu is Map && pu['id'] != null) {
        key = pu['id'].toString();
      } else {
        key = pu.toString();
      }
      buckets.putIfAbsent(key, () => []).add(u);
    }

    final List<Map<String, dynamic>> out = [];
    buckets.forEach((key, list) {
      list.sort((a, b) {
        final aEff = _parseDateDynamic(a['effective']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bEff = _parseDateDynamic(b['effective']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final cmpEff = bEff.compareTo(aEff); // newest effective first
        if (cmpEff != 0) return cmpEff;
        final aRec = _parseDateDynamic(a['recorded_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bRec = _parseDateDynamic(b['recorded_at']) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bRec.compareTo(aRec); // newest recorded_at first
      });
      out.add(list.first);
    });

    // optional: sort final results by recorded_at desc
    out.sort((a, b) {
      final ar = _parseDateDynamic(a['recorded_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final br = _parseDateDynamic(b['recorded_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return br.compareTo(ar);
    });

    return out;
  }

  Widget _buildPriceExplorer() {
    final cards = _filteredPriceCards();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Include both current and near-future updates (within next 30 days)
    final List<Map<String, dynamic>> relevantUpdates = cards.where((c) {
      final effRaw = c['effective'];
      final effDt = _parseDateDynamic(effRaw);
      if (effDt == null) return false;

      final now = DateTime.now();
      final effDate = DateTime(effDt.year, effDt.month, effDt.day);
      final today = DateTime(now.year, now.month, now.day);
      final futureLimit = today.add(const Duration(days: 30));

      // Show updates that are: past, today, or within next 30 days
      return !effDate.isAfter(futureLimit);
    }).toList();

    final uniqueCards = pickLatestPerPlotUnit(relevantUpdates);
    final displayList = uniqueCards;

    return Column(
      children: [
        // Search and filter section with modern design
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1f1f1f) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search field
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  controller: _priceSearchCtr,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.grey.shade900,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      size: 22,
                    ),
                    hintText: 'Search estate or plot size...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Sort and filter controls
              LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                return isWide
                    ? Row(
                        children: [
                          Expanded(
                            child: _buildSortDropdown(isDark),
                          ),
                          const SizedBox(width: 12),
                          _buildPromoChip(isDark),
                        ],
                      )
                    : Column(
                        children: [
                          _buildSortDropdown(isDark),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildPromoChip(isDark),
                          ),
                        ],
                      );
              }),
            ],
          ),
        ),

        // Results count with icon
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${displayList.length} ${displayList.length == 1 ? 'update' : 'updates'}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (_priceSearchCtr.text.isNotEmpty || _promoOnly)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _priceSearchCtr.clear();
                      _promoOnly = false;
                    });
                  },
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),

        // Grid of cards
        AnimatedBuilder(
          animation: _staggerAnim,
          builder: (context, _) {
            return LayoutBuilder(builder: (ctx, cons) {
              final cols =
                  cons.maxWidth > 1000 ? 3 : (cons.maxWidth > 600 ? 2 : 1);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: displayList.isEmpty
                    ? _buildEmptyState(isDark)
                    : GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: displayList.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio:
                              cols == 1 ? 1.45 : (cols == 2 ? 1.35 : 1.25),
                        ),
                        itemBuilder: (ctx, i) {
                          final c = displayList[i];
                          return TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 300 + (i * 50)),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 20 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              );
                            },
                            child: _buildPriceCard(c),
                          );
                        },
                      ),
              );
            });
          },
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSortDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sort_rounded,
            size: 18,
            color: isDark ? Colors.white60 : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: _priceSort,
              isExpanded: true,
              isDense: true,
              items: const [
                DropdownMenuItem(
                  value: 'newest',
                  child: Text('Newest First'),
                ),
                DropdownMenuItem(
                  value: 'biggest_up',
                  child: Text('Largest Increase'),
                ),
                DropdownMenuItem(
                  value: 'biggest_down',
                  child: Text('Largest Decrease'),
                ),
                DropdownMenuItem(
                  value: 'highest_price',
                  child: Text('Highest Price'),
                ),
                DropdownMenuItem(
                  value: 'promo_first',
                  child: Text('Promotions First'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _priceSort = v);
              },
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(14),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoChip(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _promoOnly = !_promoOnly),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: _promoOnly
              ? LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ],
                )
              : null,
          color: _promoOnly
              ? null
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _promoOnly
                ? Theme.of(context).colorScheme.primary
                : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.shade200),
            width: _promoOnly ? 2 : 1,
          ),
          boxShadow: _promoOnly
              ? [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _promoOnly ? Icons.local_offer : Icons.local_offer_outlined,
              size: 18,
              color: _promoOnly
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
            Text(
              'Promo Only',
              style: TextStyle(
                fontSize: 14,
                fontWeight: _promoOnly ? FontWeight.w700 : FontWeight.w500,
                color: _promoOnly
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.grey.shade900),
              ),
            ),
            if (_promoOnly) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No updates found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(Map<String, dynamic> c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final promo = c['promo'];
    final percent = (c['percent_change'] ?? 0) is num
        ? (c['percent_change'] as num).toDouble()
        : 0.0;
    final up = percent >= 0;
    final estateName = c['estate_name'] ?? '-';
    final plotSize = (c['plot_unit'] != null && c['plot_unit'] is Map)
        ? (c['plot_unit']['size'] ?? '-').toString()
        : '-';
    final effectiveDate = c['effective']?.toString() ?? '';
    final isFutureDate = _isFutureDate(effectiveDate);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.9, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E1E1E), const Color(0xFF2C2C2C)]
                    : [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.5)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estate name and promo badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        estateName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.grey.shade900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (promo != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFFA500)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_offer, color: Colors.white, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              '-${promo['discount']}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  plotSize,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 12),

                // Price + percentage section
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (promo != null && c['promo_price'] != null) ...[
                            Text(
                              _formatNGN(c['promo_price']),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Colors.deepOrangeAccent,
                              ),
                            ),
                            Text(
                              _formatNGN(c['current']),
                              style: TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ] else
                            Text(
                              _formatNGN(c['current']),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: up
                                    ? Colors.greenAccent.shade400
                                    : Colors.redAccent,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            'Prev: ${_formatNGN(c['previous'])}',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.white54 : Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: up
                            ? Colors.greenAccent.withOpacity(0.15)
                            : Colors.redAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            up ? Icons.trending_up : Icons.trending_down,
                            color: up ? Colors.greenAccent : Colors.redAccent,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${percent.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              color:
                                  up ? Colors.greenAccent : Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Effective date
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFutureDate
                        ? Colors.tealAccent.withOpacity(0.15)
                        : Colors.blueGrey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 12),
                      const SizedBox(width: 6),
                      Text(
                        isFutureDate ? 'Effective On' : 'Effective Since',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? Colors.white70 : Colors.blueGrey.shade800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateDisplay(effectiveDate),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blueGrey.shade900,
                        ),
                      ),
                    ],
                  ),
                ),

                if (c['notes'] != null &&
                    c['notes'].toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.amber.shade900.withOpacity(0.15)
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 12,
                            color: isDark
                                ? Colors.amber.shade300
                                : Colors.amber.shade800),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c['notes'].toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.amber.shade200
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        _openPriceDetail((c['id'] as num).toInt()),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                    label: const Text(
                      'View Details',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.tealAccent : Colors.teal.shade700,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = (_clientName != null && _clientName!.isNotEmpty)
        ? _clientName!
        : 'Client Dashboard';

    return AppLayout(
      pageTitle: 'Dashboard',
      token: widget.token,
      side: AppSide.client,
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        bottomNavigationBar:
            ClientBottomNav(currentIndex: 0, token: widget.token, chatBadge: 0),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchDashboard,
            color: Theme.of(context).colorScheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                // header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 20),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 28,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.grey.shade800,
                                    ) ??
                                TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 28,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.grey.shade800,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Home / Dashboard',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 14),
                          )
                        ],
                      ),
                    ),
                  ]),
                ),

                if (_loading)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade600),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Failed to load: $_error',
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                          TextButton(
                            onPressed: _fetchDashboard,
                            child: Text(
                              'Retry',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                // stats
                if (!_loading) _buildTopStats(),

                // active promos
                if (!_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Active Promotional Offers',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Running promotions — limited time',
                                    style: TextStyle(color: Colors.grey),
                                  )
                                ],
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => PromotionsListPage(
                                            token: widget.token))),
                                child: const Text('View All'),
                              )
                            ],
                          ),
                        ),
                        _buildPromotionsCarousel()
                      ],
                    ),
                  ),

                // price explorer
                if (!_loading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Latest Price Increments',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20),
                              ),
                              // TextButton.icon(
                              //   onPressed: () => Navigator.of(context).push(
                              //       MaterialPageRoute(
                              //           builder: (_) => PromotionsListPage(
                              //               token: widget.token))),
                              //   icon: const Icon(Icons.local_offer_outlined),
                              //   label: const Text('Promotions'),
                              // )
                            ],
                          ),
                        ),
                        _buildPriceExplorer()
                      ],
                    ),
                  ),

                const SizedBox(height: 24)
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------
// Price Detail Dialog
// ---------------------------

class PriceDetailDialog extends StatefulWidget {
  final dynamic api;
  final String token;
  final int priceHistoryId;

  const PriceDetailDialog({
    super.key,
    required this.api,
    required this.token,
    required this.priceHistoryId,
  });

  @override
  State<PriceDetailDialog> createState() => _PriceDetailDialogState();
}

class _PriceDetailDialogState extends State<PriceDetailDialog>
    with TickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await widget.api
          .getPriceUpdateById(widget.priceHistoryId, token: widget.token);
      setState(() => _data = resp);
      _controller.forward();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.95)
                  : Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _loading
                ? _buildLoader(context)
                : (_error != null
                    ? _buildError(context)
                    : FadeTransition(
                        opacity: _controller,
                        child: ScaleTransition(
                          scale: CurvedAnimation(
                              parent: _controller, curve: Curves.easeOutBack),
                          child: _buildContent(context, isDark),
                        ),
                      )),
          ),
        ),
      ),
    );
  }

  Widget _buildLoader(BuildContext context) => SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 3),
              const SizedBox(height: 16),
              Text("Fetching price details...",
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );

  Widget _buildError(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            Text("Error loading data",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _load,
              child: const Text("Retry"),
            )
          ],
        ),
      );

  Widget _buildContent(BuildContext context, bool isDark) {
    final percent = (_data?['percent_change'] as num?)?.toDouble() ?? 0.0;
    final isIncrease = percent >= 0;
    final promo = _data?['promo'];
    final promoActive = promo != null && promo['active'] == true;

    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 420;
      return Padding(
        padding: EdgeInsets.all(narrow ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.price_change_rounded,
                        color: Colors.teal, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Price Update Overview",
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  )
                ],
              ),
              const Divider(height: 24),

              // ESTATE NAME
              Text(
                _data?['estate_name'] ?? "—",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
              ),
              const SizedBox(height: 20),

              // PRICE DETAILS
              Column(
                children: [
                  _priceTile(
                    context,
                    "Current Price",
                    _format(_data?['current']),
                    Icons.payments_rounded,
                    Colors.teal,
                    highlight: true,
                  ),
                  const SizedBox(height: 12),
                  if (promoActive)
                    _priceTile(
                      context,
                      "Promo Price",
                      _format(_data?['promo_price']),
                      Icons.local_offer_rounded,
                      Colors.amber,
                      highlight: true,
                    ),
                  const SizedBox(height: 12),
                  _changeTile(percent, isIncrease),
                ],
              ),

              const SizedBox(height: 28),

              // CLOSE BUTTON
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.done_rounded),
                  label: const Text("Close"),
                ),
              )
            ],
          ),
        ),
      );
    });
  }

  Widget _priceTile(BuildContext context, String label, String value,
      IconData icon, Color color,
      {bool highlight = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.grey.shade50.withOpacity(0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.4),
          width: highlight ? 1.4 : 0.9,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey.shade800,
                    )),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black87,
                ),
          ),
        ],
      ),
    );
  }

  Widget _changeTile(double percent, bool increase) {
    final color = increase ? Colors.greenAccent.shade400 : Colors.redAccent;
    final icon =
        increase ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween(begin: 0, end: percent.abs()),
      builder: (context, value, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.withOpacity(0.08),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                "${increase ? '+' : '-'}${value.toStringAsFixed(1)}%",
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(increase ? "Increase" : "Decrease",
                  style: TextStyle(
                      color: color.withOpacity(0.8),
                      fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  String _format(dynamic v) {
    if (v == null) return '—';
    try {
      final n = v is num ? v : double.parse(v.toString());
      return NumberFormat.currency(symbol: '₦', decimalDigits: 0).format(n);
    } catch (_) {
      return v.toString();
    }
  }
}



// ---------------------------
// Promotions List Page (Refined Design)
// ---------------------------

class PromotionsListPage extends StatefulWidget {
  final String token;
  final String? filter;
  const PromotionsListPage({Key? key, required this.token, this.filter})
      : super(key: key);

  @override
  _PromotionsListPageState createState() => _PromotionsListPageState();
}

class _PromotionsListPageState extends State<PromotionsListPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _active = [];
  Map<String, dynamic>? _paginated;
  int _page = 1;
  String _filter = 'all';
  String _q = '';
  late AnimationController _animationController;

  // Refined promo colors
  static const Color promoA = Color(0xFFFB5B78); // soft rose
  static const Color promoB = Color(0xFFFFC371); // golden peach
  static const Color promoC = Color(0xFFFFA94C); // amber accent

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _filter = widget.filter ?? 'all';
    _load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _api.listPromotions(
          token: widget.token, filter: _filter, q: _q, page: page);
      setState(() {
        _active = resp['active_promotions'] ?? [];
        _paginated = resp['promotions'];
        _page = page;
      });
      _animationController
        ..reset()
        ..forward();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _safeTruncate(String? s, int maxLen) {
    final text = (s ?? '').toString();
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions'),
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayStyle,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [promoA, promoC],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : LayoutBuilder(builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final isSmall = width < 760;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          _buildHeader(isSmall),
                          const SizedBox(height: 14),
                          if (_active.isNotEmpty) ...[
                            _buildActivePromotionsRow(width),
                            const SizedBox(height: 16),
                          ],
                          Expanded(child: _buildPromotionsGridOrList(isSmall, width)),
                          const SizedBox(height: 12),
                          _buildPaginationControls(),
                        ],
                      ),
                    );
                  }),
      ),
    );
  }

  Widget _buildHeader(bool compact) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Theme.of(context).cardColor,
              child: TextField(
                onSubmitted: (v) {
                  _q = v.trim();
                  _load(page: 1);
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: promoA),
                  hintText: 'Search promotions...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        PopupMenuButton<String>(
          tooltip: 'Filter promotions',
          onSelected: (v) {
            setState(() => _filter = v);
            _load(page: 1);
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'all', child: Text('All')),
            PopupMenuItem(value: 'active', child: Text('Active')),
            PopupMenuItem(value: 'past', child: Text('Past')),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 18, color: promoB),
                const SizedBox(width: 8),
                Text(_filter.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivePromotionsRow(double maxWidth) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _active.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final p = _active[i];
          final name = (p['name'] ?? '').toString();
          final desc = (p['description'] ?? '').toString();
          final discount = (p['discount'] ?? 0).toString();

          return FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: _animationController, curve: Interval(0.08 * i, 1.0)),
            ),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PromotionDetailPage(
                      token: widget.token, promoId: (p['id'] as num).toInt()))),
              child: Container(
                width: maxWidth < 420 ? maxWidth * 0.8 : 360,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [promoA, promoC],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: promoA.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.local_offer_rounded,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(_safeTruncate(desc, 60),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('-$discount%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          const Text('OFF',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromotionsGridOrList(bool small, double maxWidth) {
    if (_paginated == null) return const SizedBox.shrink();
    final results = List.from(_paginated!['results'] ?? []);
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer_outlined,
                size: 64, color: Theme.of(context).hintColor),
            const SizedBox(height: 12),
            Text('No promotions found',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    if (!small && maxWidth >= 900) {
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: maxWidth >= 1400 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3.2,
        ),
        itemCount: results.length,
        itemBuilder: (ctx, i) => _promotionCard(results[i], i, true),
      );
    } else {
      return ListView.separated(
        itemCount: results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _promotionCard(results[i], i, false),
      );
    }
  }

  Widget _promotionCard(dynamic p, int index, bool wide) {
    final isActive = p['is_active'] ?? false;
    final name = (p['name'] ?? '').toString();
    final desc = (p['description'] ?? '').toString();
    final discount = (p['discount'] ?? 0).toString();

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.07 * index, 1.0),
        ),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.7,
        child: Material(
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).cardColor,
          elevation: 3,
          child: InkWell(
            onTap: isActive
                ? () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PromotionDetailPage(
                        token: widget.token, promoId: (p['id'] as num).toInt())))
                : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: wide ? 12 : 10),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isActive
                          ? promoA.withOpacity(0.12)
                          : Theme.of(context)
                              .dividerColor
                              .withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_offer_rounded,
                      color: isActive ? promoA : Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isActive
                                    ? null
                                    : Theme.of(context).hintColor)),
                        const SizedBox(height: 6),
                        Text(
                          _safeTruncate(desc, 140),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isActive
                                  ? null
                                  : Theme.of(context)
                                      .hintColor
                                      .withOpacity(0.9),
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isActive
                              ? const LinearGradient(
                                  colors: [promoA, promoC])
                              : LinearGradient(colors: [
                                  Colors.grey.shade400,
                                  Colors.grey.shade400.withOpacity(0.9)
                                ]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('-$discount%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: isActive
                            ? () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => PromotionDetailPage(
                                    token: widget.token,
                                    promoId: (p['id'] as num).toInt())))
                            : null,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          elevation: 0,
                          backgroundColor:
                              isActive ? promoA : Colors.grey.shade400,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.remove_red_eye_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('View'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_paginated == null) return const SizedBox.shrink();
    final pageNum = _paginated!['page'] ?? _page;
    final totalPages = _paginated!['total_pages'] ?? 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: pageNum > 1 ? () => _load(page: pageNum - 1) : null),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).cardColor,
          ),
          child: Text('Page $pageNum of $totalPages',
              style:
                  const TextStyle(fontWeight: FontWeight.w700)),
        ),
        IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: pageNum < totalPages
                ? () => _load(page: pageNum + 1)
                : null),
      ],
    );
  }
}


// ---------------------------
// Promotion Detail Page
// ---------------------------
class PromotionDetailPage extends StatefulWidget {
  final String token;
  final int promoId;
  const PromotionDetailPage({Key? key, required this.token, required this.promoId}) : super(key: key);

  @override
  _PromotionDetailPageState createState() => _PromotionDetailPageState();
}

class _PromotionDetailPageState extends State<PromotionDetailPage> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _promo;
  late final AnimationController _animationController;

  late final Animation<double> _headerFade;
  late final Animation<double> _chipPulse;

  int? _expandedEstateId;
  final Map<int, GlobalKey> _estateKeys = {};
  final ScrollController _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

    _headerFade = CurvedAnimation(parent: _animationController, curve: const Interval(0.0, 0.35, curve: Curves.easeOut));
    _chipPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.05).chain(CurveTween(curve: Curves.easeOut)), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 40),
    ]).animate(CurvedAnimation(parent: _animationController, curve: const Interval(0.18, 0.55)));

    _load();
  }

  @override
  void dispose() {
    _listController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _api.getPromotionDetail(widget.promoId, token: widget.token);
      setState(() => _promo = resp);
      await Future.delayed(const Duration(milliseconds: 120));
      _animationController.forward();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _toggleEstateExpansion(int estateId) {
    setState(() {
      _expandedEstateId = _expandedEstateId == estateId ? null : estateId;
    });
  }

  String _formatNGN(dynamic v) {
    try {
      if (v == null) return '—';
      final numVal = v is num ? v : num.parse(v.toString());
      return NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0).format(numVal);
    } catch (_) {
      return v?.toString() ?? '—';
    }
  }

  Future<void> _scrollToEstateIndex(int index, int estateId) async {
    final key = _estateKeys[estateId];
    setState(() => _expandedEstateId = estateId);

    await Future.delayed(const Duration(milliseconds: 80));
    if (key != null && key.currentContext != null) {
      await Scrollable.ensureVisible(key.currentContext!, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic, alignment: 0.08);
      return;
    }
    try {
      final approxHeight = 140.0;
      final offset = (index * (approxHeight + 16)).clamp(0.0, _listController.position.maxScrollExtent);
      await _listController.animateTo(offset, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    } catch (_) {}
  }

  // Promotional palette
  static const Color _promoA = Color(0xFFFB5B78);
  static const Color _promoB = Color(0xFFFFC371);
  static const Color _promoC = Color(0xFFFFA94C);

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = _promo?['name'] ?? '';
    final discount = _promo?['discount'] ?? 0;
    final start = _promo?['start'] ?? '';
    final end = _promo?['end'] ?? '';

    return FadeTransition(
      opacity: _headerFade,
      child: AnimatedBuilder(
        animation: _chipPulse,
        builder: (ctx, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_promoA, _promoB]),
                boxShadow: [BoxShadow(color: _promoA.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 8))],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    // Animated emblem
                    ScaleTransition(
                      scale: _chipPulse,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, height: 1.05), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: Colors.white70),
                          const SizedBox(width: 6),
                          Flexible(child: Text('Valid: $start → $end', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ])
                      ]),
                    ),
                    const SizedBox(width: 12),
                    // Discount chip
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      ScaleTransition(
                        scale: _chipPulse,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withOpacity(0.12)),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('-${discount.toString()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                            const SizedBox(height: 2),
                            const Text('OFF', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700))
                          ]),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final desc = _promo?['description'] ?? '';
    final estates = (_promo?['estates'] as List?) ?? [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101010) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.28 : 0.04), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.card_giftcard_rounded, size: 18, color: _promoA)),
          const SizedBox(width: 10),
          Text('About this promotion', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isDark ? Colors.white : Colors.grey.shade900)),
        ]),
        const SizedBox(height: 10),
        InkWell(
          onTap: estates.isNotEmpty ? () => _scrollToEstateIndex(0, (estates[0] as Map)['id'] as int) : null,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(desc.isNotEmpty ? desc : '(No description provided)', style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey.shade700, height: 1.5)),
          ),
        ),
      ]),
    );
  }

  Widget _buildEstateRow(Map<String, dynamic> e, int idx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final estateId = e['id'] as int;
    final isExpanded = _expandedEstateId == estateId;
    final key = _estateKeys.putIfAbsent(estateId, () => GlobalKey());

    final start = 0.14 + (idx * 0.06);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final anim = CurvedAnimation(parent: _animationController, curve: Interval(start, end, curve: Curves.easeOut));

    final sizes = List<Map<String, dynamic>>.from(e['sizes'] ?? []);
    final discount = (_promo?['discount'] as num?)?.toDouble() ?? 0.0;

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero).animate(anim),
        child: Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0b0b0b) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(children: [
              InkWell(
                onTap: () => _toggleEstateExpansion(estateId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(gradient: LinearGradient(colors: [_promoA.withOpacity(0.12), _promoB.withOpacity(0.08)]), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.home_work_rounded, size: 22, color: _promoA)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e['name'] ?? '', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : Colors.grey.shade900), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(e['location'] ?? '', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(gradient: LinearGradient(colors: [_promoA, _promoB]), borderRadius: BorderRadius.circular(10)), child: Text('-${discount.toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                      const SizedBox(height: 6),
                      AnimatedRotation(turns: isExpanded ? 0.5 : 0.0, duration: const Duration(milliseconds: 300), child: Icon(Icons.expand_more_rounded, color: isDark ? Colors.white70 : Colors.grey.shade700))
                    ])
                  ]),
                ),
              ),

              // collapsed CTA row
              if (!isExpanded)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.03),
                  child: InkWell(
                    onTap: () => _scrollToEstateIndex(idx, estateId),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.price_check_rounded, size: 18, color: _promoA),
                      const SizedBox(width: 8),
                      Text('CLICK TO VIEW PLOT PRICES', style: TextStyle(fontWeight: FontWeight.w800, color: _promoA)),
                    ]),
                  ),
                ),

              // expanded sizes
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Column(
                    children: sizes.map((size) {
                      final curr = size['current'] ?? size['amount'];
                      final currHas = curr != null;
                      final currStr = currHas ? _formatNGN(curr) : 'NO AMOUNT SET';
                      final promoPrice = currHas ? ((curr as num) * (100 - discount) / 100) : null;
                      final promoStr = promoPrice != null ? _formatNGN(promoPrice) : 'NO AMOUNT SET';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF0a0a0a) : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.crop_square_rounded, size: 18, color: _promoA)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(size['size']?.toString() ?? '-', style: TextStyle(fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.grey.shade900))),
                          const SizedBox(width: 12),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Row(children: [
                              if (promoPrice != null) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFff6b6b), Color(0xFFffa500)]), borderRadius: BorderRadius.circular(6)), child: Text('-${discount.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))),
                              const SizedBox(width: 6),
                              Text(promoStr, style: TextStyle(fontWeight: FontWeight.w900, color: promoPrice != null ? (isDark ? Colors.green.shade300 : Colors.green.shade700) : (isDark ? Colors.orange.shade300 : Colors.orange.shade700))),
                            ]),
                            const SizedBox(height: 6),
                            Text(currStr, style: TextStyle(decoration: promoPrice != null ? TextDecoration.lineThrough : null, color: currHas ? (promoPrice != null ? (isDark ? Colors.white38 : Colors.grey.shade500) : (isDark ? Colors.white70 : Colors.grey.shade700)) : (isDark ? Colors.orange.shade300 : Colors.orange.shade700))),
                          ])
                        ]),
                      );
                    }).toList(),
                  ),
                ),
                crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 280),
              )
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ensure status bar icons contrast the promotional header if shown
    SystemUiOverlayStyle overlay = SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, statusBarBrightness: Brightness.dark);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Promotion Details', style: TextStyle(fontWeight: FontWeight.w800)),
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.grey.shade900,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: overlay,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_promoA, _promoB]))),
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 14),
                  Text('Loading promotion...', style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade700))
                ]),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400)),
                        const SizedBox(height: 14),
                        Text('Error loading promotion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.grey.shade900)),
                        const SizedBox(height: 8),
                        Text('$_error', textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade700)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: _promoA)),
                      ]),
                    ),
                  )
                : LayoutBuilder(builder: (ctx, cons) {
                    final estates = (_promo?['estates'] as List?) ?? [];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // header & description
                        _buildHeader(context),
                        _buildDescription(context),
                        const SizedBox(height: 12),

                        // estates title
                        Row(children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.grid_view_rounded, size: 18, color: _promoA)),
                          const SizedBox(width: 10),
                          Text('Promo Estates', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : Colors.grey.shade900)),
                          const SizedBox(width: 8),
                          if (estates.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _promoA.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('${estates.length}', style: const TextStyle(fontWeight: FontWeight.w800))),
                        ]),
                        const SizedBox(height: 10),

                        // estates list (Expanded) - uses ListView.builder so content is scrollable and won't overflow
                        Expanded(
                          child: estates.isEmpty
                              ? Center(child: Text('No estates attached', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700)))
                              : ListView.builder(
                                  controller: _listController,
                                  itemCount: estates.length,
                                  itemBuilder: (context, i) {
                                    final e = Map<String, dynamic>.from(estates[i] as Map);
                                    return _buildEstateRow(e, i);
                                  },
                                ),
                        ),
                      ]),
                    );
                  }),
      ),
    );
  }
}


// ---------------------------
// Estates List Page
// ---------------------------
class EstatesListPage extends StatefulWidget {
  final String token;
  final int? promoId;

  const EstatesListPage({Key? key, required this.token, this.promoId})
      : super(key: key);

  @override
  _EstatesListPageState createState() => _EstatesListPageState();
}

class _EstatesListPageState extends State<EstatesListPage>
    with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _estates = [];
  Map<String, dynamic>? _paginated;
  int _page = 1;
  String _q = '';
  final TextEditingController _searchController = TextEditingController();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _staggerAnimation;
  final ScrollController _scrollController = ScrollController();

  /// estateId -> highest active discount percentage
  Map<int, int> _estateDiscounts = {};

  Timer? _searchDebounce;
  VoidCallback? _searchListener;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _staggerAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: Curves.easeOutCubic,
    );

    // Search controller listener (debounced)
    _searchListener = () {
      final trimmed = _searchController.text.trim();
      if (trimmed != _q) {
        _q = trimmed;
        // debounce network calls
        _searchDebounce?.cancel();
        _searchDebounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _loadEstates(page: 1);
        });
      } else {
        // still cause rebuild for UI bits like clear button visibility
        if (mounted) setState(() {});
      }
    };
    _searchController.addListener(_searchListener!);

    // initial UI fades in
    _fadeController.forward();

    // initial load
    _loadEstates();

    _scrollController.addListener(() {
      if (mounted) setState(() {}); // toggles FAB visibility
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (_searchListener != null)
      _searchController.removeListener(_searchListener!);
    _searchController.dispose();
    _fadeController.dispose();
    _staggerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Explicit search trigger (keyboard submit or icon)
  void _doSearch() {
    _searchDebounce?.cancel();
    _q = _searchController.text.trim();
    FocusScope.of(context).unfocus();
    _loadEstates(page: 1);
  }

  // Helper: parse discount values from many shapes
  int? _parseDiscount(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    final s = v.toString();
    final n = num.tryParse(s);
    return n != null ? n.round() : null;
  }

  // Inspect estate payload and active promos to build estate -> top discount map
  Future<void> _computeDiscountsFromEstates(List<dynamic> estatesList) async {
    final Map<int, int> discounts = {};

    for (var e in estatesList) {
      if (e is Map) {
        final dynamic idRaw = e['id'];
        int? id;
        if (idRaw is num)
          id = idRaw.toInt();
        else if (idRaw != null) id = int.tryParse(idRaw.toString());
        if (id == null) continue;

        int? best;
        for (final listKey in [
          'promotional_offers',
          'promos',
          'promotions',
          'promotional_offers_preview',
          'promotions_preview',
          'estates_promos'
        ]) {
          final pList = e[listKey];
          if (pList is List) {
            for (final p in pList) {
              if (p is Map) {
                final cand = _parseDiscount(
                    p['discount_pct'] ?? p['discount'] ?? p['percent']);
                if (cand != null) {
                  if (best == null || cand > best) best = cand;
                }
              } else {
                final cand = _parseDiscount(p);
                if (cand != null) {
                  if (best == null || cand > best) best = cand;
                }
              }
            }
          }
        }

        final estateLevel = _parseDiscount(e['discount'] ?? e['discount_pct']);
        if (estateLevel != null) {
          if (best == null || estateLevel > best) best = estateLevel;
        }

        if (best != null) discounts[id] = best;
      }
    }

    // Fallback: call active promotions endpoint and map estates -> discounts
    try {
      final activePromos = await _api.listActivePromotions(token: widget.token);
      if (activePromos is List) {
        for (final p in activePromos) {
          if (p is Map) {
            final dVal = p['discount_pct'] ?? p['discount'];
            final disc = _parseDiscount(dVal);
            if (disc == null) continue;
            final estatesForPromo = p['estates'];
            if (estatesForPromo is List) {
              for (final estEntry in estatesForPromo) {
                if (estEntry is Map && estEntry['id'] != null) {
                  int? eid;
                  final idRaw = estEntry['id'];
                  if (idRaw is num)
                    eid = idRaw.toInt();
                  else
                    eid = int.tryParse(idRaw.toString());
                  if (eid == null) continue;
                  final existing = discounts[eid];
                  if (existing == null || disc > existing)
                    discounts[eid] = disc;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Active promos fetch failed: $e');
    }

    if (mounted) setState(() => _estateDiscounts = discounts);
  }

  /// Loads estates (handles list, paginated maps, single object shapes)
  Future<void> _loadEstates({int page = 1}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    debugPrint('Estates -> loading page=$page q="$_q"');

    try {
      final dynamic resp = await _api.listEstates(
        token: widget.token,
        q: _q.isEmpty ? null : _q,
        page: page,
      );

      debugPrint('Estates -> response type: ${resp.runtimeType}');

      if (resp is List) {
        final list = List.from(resp);
        debugPrint('🔵 Received plain List with ${list.length} estates');
        if (list.isNotEmpty && list[0] is Map) {
          final firstEstate = list[0] as Map;
          debugPrint('   First estate keys: ${firstEstate.keys.toList()}');
          debugPrint('   Has promotional_offers? ${firstEstate.containsKey('promotional_offers')}');
        }
        if (mounted) {
          setState(() {
            _estates = list;
            _paginated = {
              'results': _estates,
              'count': _estates.length,
              'next': null,
              'previous': null,
              'total_pages': 1,
            };
            _page = page;
          });
        }
      } else if (resp is Map) {
        final map = Map<String, dynamic>.from(resp);
        final dynamic maybeResults = map['results'];
        if (maybeResults is List) {
          debugPrint('🔵 Received paginated Map with ${(maybeResults as List).length} estates in results');
          if (maybeResults.isNotEmpty && maybeResults[0] is Map) {
            final firstEstate = maybeResults[0] as Map;
            debugPrint('   First estate keys: ${firstEstate.keys.toList()}');
            debugPrint('   Has promotional_offers? ${firstEstate.containsKey('promotional_offers')}');
            if (firstEstate.containsKey('promotional_offers')) {
              debugPrint('   promotional_offers value: ${firstEstate['promotional_offers']}');
            }
          }
          if (mounted) {
            setState(() {
              _estates = List.from(maybeResults);
              _paginated = map;
              _page = page;
            });
          }
        } else if (map.containsKey('id') || map.containsKey('name')) {
          // single estate returned
          if (mounted) {
            setState(() {
              _estates = [map];
              _paginated = {
                'results': _estates,
                'count': 1,
                'next': null,
                'previous': null,
                'total_pages': 1,
              };
              _page = page;
            });
          }
        } else {
          // attempt to find list-like keys
          List<dynamic>? candidateList;
          for (final key in ['results', 'data', 'items']) {
            if (map[key] is List) {
              candidateList = List.from(map[key] as List);
              break;
            }
          }
          if (candidateList != null) {
            if (mounted) {
              setState(() {
                _estates = candidateList!;
                _paginated = map;
                _page = page;
              });
            }
          } else {
            // unknown map shape - treat as empty results but keep pagination metadata
            if (mounted) {
              setState(() {
                _estates = [];
                _paginated = map;
                _page = page;
              });
            }
          }
        }
      } else {
        // unknown shape
        if (mounted) {
          setState(() {
            _estates = [];
            _paginated = null;
            _page = page;
          });
        }
      }

      // compute discounts & run animations
      await _computeDiscountsFromEstates(_estates);
      _staggerController.reset();
      await Future.delayed(const Duration(milliseconds: 60));
      _staggerController.forward();
      _fadeController.forward(from: 0.0);
    } catch (e, st) {
      debugPrint('Estates -> error: $e\n$st');
      if (mounted) setState(() => _error = e.toString());
      _fadeController.forward(from: 0.0);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showEstateSizesModal(Map<String, dynamic> estate) async {
    await showDialog(
      context: context,
      builder: (context) =>
          EstateSizesModal(token: widget.token, estate: estate),
    );
  }

  // Robust date extractor & formatter
  String _formatAddedDate(dynamic candidate) {
    try {
      if (candidate == null) return 'N/A';
      if (candidate is String) {
        final parsed = DateTime.tryParse(candidate);
        if (parsed != null) return DateFormat('yyyy-MM-dd').format(parsed);
        final match = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(candidate);
        if (match != null) return match.group(0)!;
      } else if (candidate is DateTime) {
        return DateFormat('yyyy-MM-dd').format(candidate);
      } else if (candidate is int) {
        // seconds or milliseconds
        try {
          if (candidate > 9999999999) {
            final dt = DateTime.fromMillisecondsSinceEpoch(candidate);
            return DateFormat('yyyy-MM-dd').format(dt);
          } else {
            final dt = DateTime.fromMillisecondsSinceEpoch(candidate * 1000);
            return DateFormat('yyyy-MM-dd').format(dt);
          }
        } catch (_) {}
      } else {
        final s = candidate.toString();
        final parsed = DateTime.tryParse(s);
        if (parsed != null) return DateFormat('yyyy-MM-dd').format(parsed);
      }
    } catch (_) {}
    return 'N/A';
  }

  bool get _showScrollToTop =>
      _scrollController.hasClients && _scrollController.offset > 300;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E21) : const Color(0xFFF8F9FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        title: Text(
          'All Estates',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: isDark ? Colors.white : const Color(0xFF1A1D2E),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          // Filter button with animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 0.1,
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon:
                        Icon(Icons.tune, color: colorScheme.primary, size: 22),
                    onPressed: () {},
                    tooltip: 'Filter estates',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: AnimatedScale(
        duration: const Duration(milliseconds: 300),
        scale: _showScrollToTop ? 1.0 : 0.0,
        curve: Curves.easeOutBack,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.primary.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic);
            },
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            elevation: 0,
            child: const Icon(Icons.arrow_upward, size: 24),
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: RefreshIndicator(
            onRefresh: () => _loadEstates(page: 1),
            color: colorScheme.primary,
            child: _loading
                ? _buildLoadingState()
                : _error != null
                    ? _buildErrorState()
                    : _buildContentState(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2746) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(strokeWidth: 3),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Loading estates...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.white70 : const Color(0xFF6C757D),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colorScheme.error,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1D2E),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white60 : const Color(0xFF6C757D),
                  ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _loadEstates(page: 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Try Again',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 24),
          if (_estates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.home_work,
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_estates.length} ${_estates.length == 1 ? 'Estate' : 'Estates'}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: _estates.isEmpty
                ? _buildEmptyState()
                : LayoutBuilder(builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount =
                        width > 1000 ? 3 : (width > 600 ? 2 : 1);
                    final gap = 16.0;
                    final totalGapWidth = gap * (crossAxisCount - 1);
                    final cardWidth = (width - totalGapWidth) / crossAxisCount;
                    final desiredCardHeight = 270.0;
                    final childAspectRatio =
                        (cardWidth / desiredCardHeight).clamp(0.6, 2.5);

                    return GridView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: _estates.length,
                      itemBuilder: (ctx, i) {
                        final estate = _estates[i];
                        final Map<String, dynamic> map = (estate is Map)
                            ? Map<String, dynamic>.from(estate)
                            : {'name': estate?.toString() ?? 'Estate'};

                        // build per-item stagger animation
                        final start = (i * 0.05).clamp(0.0, 0.9);
                        final end = (start + 0.6).clamp(0.0, 1.0);

                        final anim = CurvedAnimation(
                          parent: _staggerController,
                          curve: Interval(start, end, curve: Curves.easeOut),
                        );

                        return AnimatedEstateCard(
                          animation: anim,
                          map: map,
                          addedDate: _formatAddedDate(map['created_at'] ??
                              map['date_added'] ??
                              map['date'] ??
                              map['added_at']),
                          onTap: () => _showEstateSizesModal(map),
                        );
                      },
                    );
                  }),
          ),
          if (_paginated != null &&
              (_paginated!['next'] != null || _paginated!['previous'] != null))
            _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.apartment,
                    size: 80,
                    color: colorScheme.primary.withOpacity(0.5),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'No estates found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1D2E),
                ),
          ),
          const SizedBox(height: 12),
          Text(
            _q.isEmpty
                ? 'There are currently no estates available.'
                : 'Try adjusting your search criteria.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white60 : const Color(0xFF6C757D),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2746) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1A1D2E),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.primary,
                          size: 22,
                        ),
                        hintText: 'Search estates by name or location...',
                        hintStyle: TextStyle(
                          color:
                              isDark ? Colors.white38 : const Color(0xFF6C757D),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _doSearch(),
                    ),
                  ),

                  // Clear button visible when there's text
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, val, child) {
                      final hasText = val.text.isNotEmpty;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: hasText
                            ? Container(
                                key: const ValueKey('clear_btn'),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _doSearch();
                                  },
                                  tooltip: 'Clear search',
                                ),
                              )
                            : const SizedBox(key: ValueKey('empty'), width: 8),
                      );
                    },
                  ),

                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.search,
                          color: Colors.white, size: 22),
                      onPressed: _doSearch,
                      tooltip: 'Search',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final totalPages = _paginated!['total_pages'] ?? 1;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2746) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Previous button
                Container(
                  decoration: BoxDecoration(
                    color: _page > 1
                        ? colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: _page > 1
                          ? colorScheme.primary
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                    onPressed: _page > 1
                        ? () {
                            _loadEstates(page: _page - 1);
                          }
                        : null,
                    tooltip: _page > 1 ? 'Previous page' : null,
                  ),
                ),

                const SizedBox(width: 8),

                // Page indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.filter_none,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '$_page',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        ' / $totalPages',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Next button
                Container(
                  decoration: BoxDecoration(
                    color: _page < totalPages
                        ? colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: _page < totalPages
                          ? colorScheme.primary
                          : (isDark ? Colors.white24 : Colors.black26),
                    ),
                    onPressed: _page < totalPages
                        ? () {
                            _loadEstates(page: _page + 1);
                          }
                        : null,
                    tooltip: _page < totalPages ? 'Next page' : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------
// Animated Estate Card
// ---------------------------
class AnimatedEstateCard extends StatelessWidget {
  final Animation<double> animation;
  final Map<String, dynamic> map;
  final VoidCallback onTap;
  final String addedDate;

  const AnimatedEstateCard({
    Key? key,
    required this.animation,
    required this.map,
    required this.onTap,
    required this.addedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
              .animate(animation),
          child: _EstateCard(
            map: map,
            onTap: onTap,
            addedDate: addedDate,
          ),
        ),
      ),
    );
  }
} 

class _EstateCard extends StatefulWidget {
  final Map<String, dynamic> map;
  final VoidCallback onTap;
  final String addedDate;

  const _EstateCard({
    Key? key,
    required this.map,
    required this.onTap,
    required this.addedDate,
  }) : super(key: key);

  @override
  State<_EstateCard> createState() => _EstateCardState();
}

class _EstateCardState extends State<_EstateCard>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  List<dynamic> _promotionalOffers = [];
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _extractPromotionalOffers();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _extractPromotionalOffers() {
    // Extract promotional offers from various possible fields in the API response
    debugPrint(
        '\n═══════════════════════════════════════════════════════════');
    debugPrint('🏢 EXTRACTING PROMOS FOR: ${widget.map['name']}');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📋 Estate map keys: ${widget.map.keys.toList()}');
    debugPrint('📦 Full estate map: ${widget.map}');

    final promos = widget.map['promotional_offers'] ??
        widget.map['promotionalOffers'] ??
        widget.map['promos'] ??
        widget.map['promotions'] ??
        [];
    
    debugPrint('🔍 Checking field "promotional_offers": ${widget.map['promotional_offers']}');
    debugPrint('🔍 Checking field "promotionalOffers": ${widget.map['promotionalOffers']}');
    debugPrint('🔍 Checking field "promos": ${widget.map['promos']}');
    debugPrint('🔍 Checking field "promotions": ${widget.map['promotions']}');

    debugPrint(
        'Estate ${widget.map['name']}: Found ${promos is List ? promos.length : 0} promotional offers');
    if (promos is List && promos.isNotEmpty) {
      debugPrint('First promo details: ${promos[0]}');
      debugPrint('All promo data: $promos');

      // Count active vs inactive
      int activeCount = 0;
      int inactiveCount = 0;
      for (var promo in promos) {
        final isActive = promo['is_active'] == true || promo['active'] == true;
        if (isActive) {
          activeCount++;
          debugPrint(
              '  ✅ ACTIVE: ${promo['name']} (${promo['discount_pct'] ?? promo['discount']}%)');
        } else {
          inactiveCount++;
          debugPrint(
              '  ⏰ INACTIVE: ${promo['name']} (${promo['discount_pct'] ?? promo['discount']}%)');
        }
      }
      debugPrint(
          'Summary: $activeCount active, $inactiveCount inactive promos');
    } else {
      debugPrint(
          'No promotional offers found or wrong data type: ${promos.runtimeType}');
    }

    if (promos is List) {
      setState(() {
        _promotionalOffers = promos;
      });
      debugPrint(
          '_promotionalOffers state updated with ${promos.length} items');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.map['name'] ?? 'Estate';
    final location = widget.map['location'] ?? '';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // DEBUG: Print every time widget builds
    debugPrint('🎨 Building estate card for: $name | Promos count: ${_promotionalOffers.length}');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: _isHovering ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? const Color(0xFF1E2746) : Colors.white,
                  border: Border.all(
                    color: _isHovering
                        ? colorScheme.primary.withOpacity(0.3)
                        : colorScheme.primary.withOpacity(0.08),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary
                          .withOpacity(_isHovering ? 0.15 : 0.06),
                      blurRadius: _isHovering ? 20 : 12,
                      offset: Offset(0, _isHovering ? 10 : 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      // Subtle gradient overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary.withOpacity(0.02),
                                Colors.transparent,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with icon and text
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                // Icon with gradient background
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.primary.withOpacity(0.15),
                                        colorScheme.primary.withOpacity(0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color:
                                          colorScheme.primary.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.apartment_rounded,
                                    color: colorScheme.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1D2E),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      if (location.isNotEmpty)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 14,
                                              color: colorScheme.primary
                                                  .withOpacity(0.6),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                location,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: isDark
                                                      ? Colors.white60
                                                      : const Color(0xFF6C757D),
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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

                          // Divider
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 18),
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  colorScheme.primary.withOpacity(0.15),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          // Added date and promo count
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 12,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        widget.addedDate,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Promo count badge
                                if (_promotionalOffers.isNotEmpty)
                                  _buildPromoCountBadge(
                                      colorScheme, theme, isDark),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Action button with animated shimmer
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: AnimatedBuilder(
                              animation: _shimmerAnimation,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: LinearGradient(
                                      colors: [
                                        colorScheme.primary,
                                        colorScheme.primary.withOpacity(0.85),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorScheme.primary
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: widget.onTap,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.visibility_outlined,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            SizedBox(width: 10),
                                            Text(
                                              'View Details',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
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
                        ],
                      ),

                      // 🚨 GIANT DEBUG INDICATOR - TOP LEFT (YOU MUST SEE THIS!)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _promotionalOffers.isEmpty
                                ? Colors.red  // RED = NO PROMOS
                                : Colors.green,  // GREEN = HAS PROMOS
                            border: Border.all(
                              color: Colors.yellow,
                              width: 4,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'PROMOS: ${_promotionalOffers.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      // Promotional offers badges - matching Django template logic
                      if (_promotionalOffers.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Builder(
                            builder: (context) {
                              debugPrint(
                                  '🎨 Rendering ${_promotionalOffers.length} promo badges for ${widget.map['name']}');
                              return Container(
                                decoration: BoxDecoration(
                                  // SOLID background to ensure visibility
                                  color: isDark
                                      ? Colors.black.withOpacity(0.9)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  // BRIGHT RED DEBUG BORDER - YOU SHOULD SEE THIS!
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // show up to 3 badges (matching Django |slice:":3")
                                    for (var i = 0;
                                        i < _promotionalOffers.length && i < 3;
                                        i++) ...[
                                      _buildPromoBadge(_promotionalOffers[i]),
                                      if (i < 2 &&
                                          i < _promotionalOffers.length - 1)
                                        const SizedBox(height: 6),
                                    ],
                                    // +N more (matching Django logic)
                                    if (_promotionalOffers.length > 3) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white12
                                              : Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white24
                                                : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '+${_promotionalOffers.length - 3} more',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xFF495057),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPromoBadge(dynamic promo) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Extract discount value from various possible fields
    final dynamic discountValue =
        promo['discount'] ?? promo['discount_pct'] ?? promo['percent'];
    final int? discount = discountValue is int
        ? discountValue
        : (discountValue is num
            ? discountValue.toInt()
            : int.tryParse(discountValue.toString()));

    // Extract promo name for tooltip
    final String promoName = promo['name']?.toString() ?? 'Promo';
    final String startDate = promo['start']?.toString() ?? '';
    final String endDate = promo['end']?.toString() ?? '';

    // Check if promo is active - handle various field names
    // Priority: is_active > active > date-based calculation
    bool isActive = false;

    if (promo['is_active'] != null) {
      isActive = promo['is_active'] == true;
    } else if (promo['active'] != null) {
      isActive = promo['active'] == true;
    } else if (promo['start'] != null && promo['end'] != null) {
      isActive = _isPromoActive(promo['start'], promo['end']);
    }

    debugPrint(
        '🏷️ Building badge: $promoName | Discount: $discount% | Active: $isActive | Estate: ${widget.map['name']}');

    // Format dates for tooltip
    String dateRange = '';
    if (startDate.isNotEmpty && endDate.isNotEmpty) {
      try {
        final start = DateTime.parse(startDate);
        final end = DateTime.parse(endDate);
        dateRange =
            '${DateFormat('MMM d, y').format(start)} → ${DateFormat('MMM d, y').format(end)}';
      } catch (e) {
        dateRange = '$startDate → $endDate';
      }
    }

    if (isActive) {
      // ACTIVE promo (green badge with offer icon) - matching Django bg-success
      return Tooltip(
        message: 'Active • Valid: $dateRange\n$promoName - $discount%',
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF28A745), Color(0xFF20C997)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF28A745).withOpacity(0.6),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_offer,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '-${discount ?? ''}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else {
      // NOT ACTIVE promo (gray badge with schedule icon) - matching Django bg-secondary
      return Tooltip(
        message: 'Not active • Valid: $dateRange\n$promoName - $discount%',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C757D), // matching Django bg-secondary
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '-${discount ?? ''}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  bool _isPromoActive(String startStr, String endStr) {
    try {
      final now = DateTime.now();
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);

      // Compare dates only (ignore time component) to match Django's localdate() behavior
      final nowDate = DateTime(now.year, now.month, now.day);
      final startDate = DateTime(start.year, start.month, start.day);
      final endDate = DateTime(end.year, end.month, end.day);

      // Active if: start <= today <= end (inclusive on both ends)
      return !nowDate.isBefore(startDate) && !nowDate.isAfter(endDate);
    } catch (e) {
      debugPrint('Error parsing promo dates: $e');
      return false;
    }
  }

  Widget _buildPromoCountBadge(
      ColorScheme colorScheme, ThemeData theme, bool isDark) {
    // Count active vs total promos
    int activeCount = 0;
    for (var promo in _promotionalOffers) {
      bool isActive = false;
      if (promo['is_active'] != null) {
        isActive = promo['is_active'] == true;
      } else if (promo['active'] != null) {
        isActive = promo['active'] == true;
      } else if (promo['start'] != null && promo['end'] != null) {
        isActive = _isPromoActive(promo['start'], promo['end']);
      }
      if (isActive) activeCount++;
    }

    final bool hasActivePromos = activeCount > 0;
    final String badgeText = hasActivePromos
        ? '$activeCount active'
        : '${_promotionalOffers.length} promo${_promotionalOffers.length > 1 ? 's' : ''}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasActivePromos
            ? const Color(0xFF28A745).withOpacity(0.15)
            : colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasActivePromos
              ? const Color(0xFF28A745).withOpacity(0.3)
              : colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasActivePromos ? Icons.local_offer : Icons.discount,
            size: 12,
            color:
                hasActivePromos ? const Color(0xFF28A745) : colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: hasActivePromos
                  ? const Color(0xFF28A745)
                  : colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------
// Estate Sizes Modal
// ---------------------------
class EstateSizesModal extends StatefulWidget {
  final String token;
  final Map<String, dynamic> estate;

  const EstateSizesModal({Key? key, required this.token, required this.estate})
      : super(key: key);

  @override
  _EstateSizesModalState createState() => _EstateSizesModalState();
}

class _EstateSizesModalState extends State<EstateSizesModal>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _estateDetails;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _animationController.forward();
    _loadEstateDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadEstateDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final idRaw = widget.estate['id'];
      int? estateId;
      if (idRaw is num)
        estateId = idRaw.toInt();
      else
        estateId = int.tryParse(idRaw?.toString() ?? '');

      if (estateId == null) throw Exception('Missing estate id');

      debugPrint('Loading estate details for ID: $estateId');
      final resp = await _api.getEstateModalJson(estateId, token: widget.token);
      debugPrint('Estate details response: $resp');

      // Handle different response structures
      Map<String, dynamic> details = {};
      if (resp is Map<String, dynamic>) {
        details = resp;
      } else {
        details = {
          'estate_name': widget.estate['name'],
          'sizes': resp is List ? resp : [],
          'promo': null
        };
      }

      // Ensure sizes is always a list
      if (!details.containsKey('sizes') || details['sizes'] is! List) {
        details['sizes'] = [];
      }

      debugPrint(
          'Estate details parsed: estate_name=${details['estate_name']}, sizes count=${(details['sizes'] as List).length}, promo=${details['promo']}');

      setState(() {
        _estateDetails = details;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading estate details: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return 'NO AMOUNT SET';
    try {
      final numVal = value is num ? value : double.tryParse(value.toString());
      if (numVal == null) return 'NO AMOUNT SET';

      return NumberFormat.currency(
              locale: 'en_NG', symbol: '₦', decimalDigits: 0)
          .format(numVal);
    } catch (_) {
      return 'NO AMOUNT SET';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1E2746) : Colors.white,
      elevation: 10,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.15),
                          colorScheme.primary.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      color: colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Plot Sizes & Prices',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1D2E),
                          ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: colorScheme.primary),
                      tooltip: 'Close',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Divider
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      colorScheme.primary.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (_loading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: value,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const CircularProgressIndicator(
                                    strokeWidth: 3),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading plot details...',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF6C757D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 56,
                            color: colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Error: $_error',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF6C757D),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _loadEstateDetails,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_estateDetails == null)
                const Expanded(
                    child: Center(child: Text('No details available')))
              else
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Estate name and promo badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _estateDetails!['estate_name'] ??
                                        widget.estate['name'] ??
                                        '',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF1A1D2E),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Available plot sizes and pricing details',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF6C757D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_estateDetails!['promo'] != null &&
                                (_estateDetails!['promo']['active'] == true ||
                                    _estateDetails!['promo']['is_active'] ==
                                        true))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF28A745),
                                      Color(0xFF20C997)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF28A745)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_offer,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '-${_estateDetails!['promo']['discount_pct'] ?? _estateDetails!['promo']['discount']}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Plot sizes table
                        Row(
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Available Plot Sizes:',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1D2E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_estateDetails!['sizes'] != null &&
                            (_estateDetails!['sizes'] as List).isNotEmpty)
                          Column(
                            children: [
                              for (var i = 0;
                                  i < (_estateDetails!['sizes'] as List).length;
                                  i++)
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration:
                                      Duration(milliseconds: 400 + (i * 100)),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: Opacity(
                                        opacity: value,
                                        child: _buildPlotSizeCard(
                                          (_estateDetails!['sizes'] as List)[i],
                                          isDark,
                                          colorScheme,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          )
                        else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 48,
                                      color:
                                          colorScheme.primary.withOpacity(0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No plot sizes available for this estate.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white60
                                          : const Color(0xFF6C757D),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.8)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlotSizeCard(
      dynamic size, bool isDark, ColorScheme colorScheme) {
    final amount = size['amount'] ?? size['current'] ?? size['price'];
    final discounted = size['discounted'] ?? size['promo_price'];
    final discountPct = size['discount_pct'] ?? size['discount'];
    final sizeName = size['size']?.toString() ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1828) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Size icon and name
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.15),
                    colorScheme.primary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.landscape,
                color: colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Size name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sizeName,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Plot size',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : const Color(0xFF6C757D),
                    ),
                  ),
                ],
              ),
            ),

            // Price section
            if (amount == null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'NO AMOUNT SET',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (discounted != null && discountPct != null)
              // With discount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF28A745), Color(0xFF20C997)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatCurrency(discounted),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatCurrency(amount),
                    style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: isDark ? Colors.white38 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF28A745).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_offer,
                            size: 10, color: Color(0xFF28A745)),
                        const SizedBox(width: 4),
                        Text(
                          '-$discountPct%',
                          style: const TextStyle(
                            color: Color(0xFF28A745),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              // Regular price
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _formatCurrency(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Truncate helper in extension
extension _StringExt on String {
  String truncate(int n) => length > n ? '${substring(0, n - 1)}…' : this;
}
