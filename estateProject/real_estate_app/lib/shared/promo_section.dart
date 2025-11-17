import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Promo {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String ctaLabel;
  final String? ctaRoute;
  final Color primaryColor;
  final Color secondaryColor;

  Promo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.startsAt,
    this.endsAt,
    this.ctaLabel = 'Learn more',
    this.ctaRoute,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.indigo,
  });
}

/// PromoProvider — dynamic promos can be added/removed at runtime.
class PromoProvider extends ChangeNotifier {
  final List<Promo> _promos = [];

  List<Promo> get promos => List.unmodifiable(_promos);

  bool get hasPromos => _promos.isNotEmpty;

  void addPromo(Promo promo) {
    _promos.insert(0, promo);
    notifyListeners();
  }

  void removePromoById(String id) {
    _promos.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void replacePromos(List<Promo> newPromos) {
    _promos
      ..clear()
      ..addAll(newPromos);
    notifyListeners();
  }
}

/// PromoSection — reusable, animated promo carousel.
/// - If provider exists but has no promos, this widget seeds a safe dummy promo (once).
/// - Defensive: it won't crash if PromoProvider isn't registered.
class PromoSection extends StatefulWidget {
  final double height;
  const PromoSection({super.key, this.height = 180});

  @override
  State<PromoSection> createState() => _PromoSectionState();
}

class _PromoSectionState extends State<PromoSection> with TickerProviderStateMixin {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  Timer? _clockTimer;
  int _currentPage = 0;

  late final AnimationController _cardAnim;
  late final AnimationController _shimmerAnim;

  bool _providerAvailable = true;
  bool _seededOnce = false; // ensure we seed only once

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _cardAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _shimmerAnim = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    _cardAnim.forward();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // safe autoplay start after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _safeInit());
  }

  /// Called after first frame - safe place to access provider.
  void _safeInit() {
    try {
      final provider = Provider.of<PromoProvider>(context, listen: false);
      _providerAvailable = true;

      // if provider exists and is empty, seed demo promos (only once)
      if (!_seededOnce && !provider.hasPromos) {
        provider.replacePromos(_demoPromos());
        _seededOnce = true;
      }
      _startAutoPlay(provider);
    } catch (e) {
      // PromoProvider not registered — show placeholder
      _providerAvailable = false;
    }
  }

  List<Promo> _demoPromos() {
    return [
      Promo(
        id: 'demo_p1',
        title: 'Early Bird — Save ₦1M on Guzape',
        subtitle: 'Limited units • Flexible payment plans • Call to reserve',
        imageUrl: 'assets/promo_guzape.jpg',
        endsAt: DateTime.now().add(const Duration(hours: 72)),
        ctaLabel: 'Claim Offer',
        ctaRoute: '/client-request-property',
        primaryColor: Colors.deepPurple,
        secondaryColor: Colors.pink,
      ),
      Promo(
        id: 'demo_p2',
        title: 'Wuse New Phase: Intro Pricing',
        subtitle: 'First 10 buyers get special discounts',
        imageUrl: 'assets/promo_wuse.jpg',
        endsAt: DateTime.now().add(const Duration(days: 7)),
        ctaLabel: 'View Plots',
        ctaRoute: '/client-property-list',
        primaryColor: Colors.orange,
        secondaryColor: Colors.deepOrange,
      ),
    ];
  }

  void _startAutoPlay(PromoProvider provider) {
    _autoPlayTimer?.cancel();
    if (provider.promos.length <= 1) return;
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final count = provider.promos.length;
      if (count <= 1) return;
      final next = (_currentPage + 1) % count;
      if (_pageController.hasClients) {
        _pageController.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // also reactively ensure autoplay if provider changes later
    try {
      final provider = Provider.of<PromoProvider>(context);
      _providerAvailable = true;
      // seed if still empty (and not seeded)
      if (!_seededOnce && !provider.hasPromos) {
        provider.replacePromos(_demoPromos());
        _seededOnce = true;
      }
      provider.addListener(_onProviderChange);
      // ensure autoplay
      _startAutoPlay(provider);
    } catch (_) {
      _providerAvailable = false;
    }
  }

  void _onProviderChange() {
    // Called when promos change — restart autoplay using the current provider
    try {
      final provider = Provider.of<PromoProvider>(context, listen: false);
      _startAutoPlay(provider);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _clockTimer?.cancel();
    _pageController.dispose();
    _cardAnim.dispose();
    _shimmerAnim.dispose();
    try {
      final provider = Provider.of<PromoProvider>(context, listen: false);
      provider.removeListener(_onProviderChange);
    } catch (_) {}
    super.dispose();
  }

  String _remainingText(Promo promo) {
    if (promo.endsAt == null) return '';
    final now = DateTime.now();
    final diff = promo.endsAt!.difference(now);
    if (diff.isNegative) return 'Expired';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    final secs = diff.inSeconds % 60;
    if (days > 0) return '${days}d ${hours}h left';
    if (hours > 0) return '${hours}h ${mins}m left';
    if (mins > 0) return '${mins}m ${secs}s left';
    return '${secs}s left';
  }

  LinearGradient _gradientForPromo(Promo p, double t) {
    return LinearGradient(
      begin: Alignment(-1 + t, -0.5 - t),
      end: Alignment(1 - t, 0.6 + t),
      colors: [
        p.primaryColor,
        Color.lerp(p.primaryColor, p.secondaryColor, 0.6) ?? p.secondaryColor,
        p.secondaryColor,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_providerAvailable) {
      // provider not present: show small placeholder
      return SizedBox(
        height: widget.height,
        child: Center(child: Text('Promotions unavailable', style: TextStyle(color: Colors.grey.shade600))),
      );
    }

    return Consumer<PromoProvider>(builder: (context, prov, _) {
      final promos = prov.promos;
      if (promos.isEmpty) {
        return SizedBox(
          height: widget.height,
          child: Center(child: Text("No promotions currently — check back later!", style: TextStyle(color: Colors.grey.shade600))),
        );
      }

      // Ensure autoplay uses the up-to-date provider
      _startAutoPlay(prov);

      return SizedBox(
        height: widget.height,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: promos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                    _cardAnim.forward(from: 0.0);
                  });
                },
                itemBuilder: (context, index) {
                  final promo = promos[index];
                  return AnimatedBuilder(
                    animation: Listenable.merge([_cardAnim, _shimmerAnim]),
                    builder: (context, child) {
                      final animValue = Curves.easeOut.transform(_cardAnim.value);
                      final pageOffset = 1 - ((_currentPage - index).abs().clamp(0.0, 1.0));
                      final scale = 0.96 + animValue * 0.04 + pageOffset * 0.02;
                      final translateY = 8 * (1 - animValue);
                      return Transform.translate(
                        offset: Offset(0, translateY),
                        child: Transform.scale(scale: scale, child: child),
                      );
                    },
                    child: _PromoCard(
                      key: ValueKey('promo-card-${promo.id}'),
                      promo: promo,
                      gradient: _gradientForPromo(promo, _shimmerAnim.value),
                      remainingText: _remainingText(promo),
                      onDismiss: () {
                        prov.removePromoById(promo.id);
                        Future.delayed(const Duration(milliseconds: 80), () {
                          if (mounted) setState(() {});
                        });
                      },
                      onCTA: () {
                        if (promo.ctaRoute != null) {
                          Navigator.pushNamed(context, promo.ctaRoute!);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${promo.title} — action tapped')));
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _DotsIndicator(count: promos.length, activeIndex: _currentPage),
          ],
        ),
      );
    });
  }
}

/// Visual Promo Card (no Hero to avoid duplicates)
class _PromoCard extends StatefulWidget {
  final Promo promo;
  final LinearGradient gradient;
  final String remainingText;
  final VoidCallback onCTA;
  final VoidCallback onDismiss;

  const _PromoCard({
    super.key,
    required this.promo,
    required this.gradient,
    required this.remainingText,
    required this.onCTA,
    required this.onDismiss,
  });

  @override
  State<_PromoCard> createState() => _PromoCardState();
}

class _PromoCardState extends State<_PromoCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final promo = widget.promo;
    final image = promo.imageUrl.isNotEmpty
        ? (promo.imageUrl.startsWith('http') ? NetworkImage(promo.imageUrl) : AssetImage(promo.imageUrl) as ImageProvider)
        : const AssetImage('assets/logo.png');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.black.withOpacity(0.04))),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                            child: Text('PROMO', style: TextStyle(color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          const Spacer(),
                          IconButton(onPressed: widget.onDismiss, icon: Icon(Icons.close, color: Colors.white70), tooltip: 'Dismiss'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _ShimmerText(text: promo.title),
                      const SizedBox(height: 6),
                      Text(promo.subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        children: [
                          if (widget.remainingText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [const Icon(Icons.timer, size: 14, color: Colors.white), const SizedBox(width: 8), Text(widget.remainingText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
                            ),
                          const Spacer(),
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, child) {
                              final t = _pulse.value;
                              final scale = 1.0 + 0.04 * t;
                              return Transform.scale(
                                scale: scale,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                  onPressed: widget.onCTA,
                                  child: Text(widget.promo.ctaLabel),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.95, end: 1.05),
                    duration: const Duration(milliseconds: 1600),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.02)]), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 12)]),
                          child: ClipOval(child: Image(image: image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40, color: Colors.white24))),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;
  const _DotsIndicator({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? Colors.blueAccent : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
              boxShadow: active ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : null,
            ),
          );
        }),
      ),
    );
  }
}

class _ShimmerText extends StatefulWidget {
  final String text;
  const _ShimmerText({required this.text});
  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;
  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final gradient = LinearGradient(
          colors: [Colors.white.withOpacity(0.95), Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.95)],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment(-1 + 2 * _shimmer.value, -0.2),
          end: Alignment(1 + 2 * _shimmer.value, 0.2),
        );
        return ShaderMask(shaderCallback: (rect) => gradient.createShader(Rect.fromLTWH(0, 0, rect.width, rect.height)), blendMode: BlendMode.srcIn, child: Text(widget.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));
      },
    );
  }
}
