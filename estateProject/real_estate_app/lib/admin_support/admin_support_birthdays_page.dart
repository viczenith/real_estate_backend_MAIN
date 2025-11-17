import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:real_estate_app/admin_support/admin_support_bottom_nav.dart';
import 'package:real_estate_app/admin_support/admin_support_layout.dart';
import 'package:real_estate_app/core/api_service.dart';

class AdminSupportBirthdaysPage extends StatefulWidget {
  final String token;

  const AdminSupportBirthdaysPage({super.key, required this.token});

  @override
  State<AdminSupportBirthdaysPage> createState() => _AdminSupportBirthdaysPageState();
}

class _CelebrationGlowPainter extends CustomPainter {
  final double progress;

  const _CelebrationGlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final baseOpacity = 0.28 + 0.12 * sin(progress * pi * 2);

    void drawGlow(Offset center, double radius, List<Color> colors, double opacity) {
      final gradientColors = [
        ...colors.map((c) => c.withOpacity(opacity)),
        Colors.transparent,
      ];
      final stops = List.generate(gradientColors.length, (index) {
        if (gradientColors.length == 1) {
          return 1.0;
        }
        return index / (gradientColors.length - 1);
      }).map((value) => value.toDouble()).toList();

      final paint = Paint()
        ..shader = RadialGradient(
          colors: gradientColors,
          stops: stops,
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final glowCenters = [
      Offset(size.width * (0.25 + 0.1 * sin(progress * pi)), size.height * 0.2),
      Offset(size.width * (0.75 - 0.08 * cos(progress * pi * 1.5)), size.height * 0.35),
      Offset(size.width * 0.5, size.height * (0.85 - 0.08 * sin(progress * pi * 2))),
    ];

    final glowColors = [
      [const Color(0xFFFFFFFF), const Color(0xFFFFE066)],
      [const Color(0xFFFFFFFF), const Color(0xFF9E7BFF)],
      [const Color(0xFFFFFFFF), const Color(0xFFFF8E72)],
    ];

    final radii = [
      size.shortestSide * 0.45,
      size.shortestSide * 0.38,
      size.shortestSide * 0.5,
    ];

    for (var i = 0; i < glowCenters.length; i++) {
      drawGlow(glowCenters[i], radii[i], glowColors[i], baseOpacity);
    }

    final sparkPaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    final sparkCenters = [
      Offset(size.width * 0.18, size.height * 0.55),
      Offset(size.width * 0.82, size.height * 0.62),
      Offset(size.width * 0.65, size.height * 0.18),
    ];

    final pulse = 1 + 0.15 * sin(progress * pi * 4);
    for (final center in sparkCenters) {
      canvas.drawCircle(center, 10 * pulse, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationGlowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _AdminSupportBirthdaysPageState extends State<AdminSupportBirthdaysPage>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  Timer? _midnightRefreshTimer;
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));
  final PageController _spotlightController = PageController(viewportFraction: 0.9);
  Timer? _spotlightTimer;
  int _currentSpotlightIndex = 0;
  AudioPlayer? _audioPlayer;
  Uint8List? _cachedCelebrationTone;
  bool _hasPlayedCelebration = false;

  late final AnimationController _backgroundController;
  late final Animation<double> _backgroundShift;

  bool _loading = true;
  String? _error;
  List<BirthdayEntry> _today = const [];
  List<BirthdayEntry> _thisWeek = const [];
  List<BirthdayEntry> _thisMonth = const [];
  DateTime? _generatedAt;
  DateTimeRange? _weekRange;
  DateTimeRange? _monthRange;

  @override
  void initState() {
    super.initState();
    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _backgroundShift =
        CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOutSine);
    _backgroundController.repeat(reverse: true);
    _loadSummary();
    _scheduleMidnightRefresh();
  }

  Future<void> _loadSummary({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final payload = await _api.fetchSupportBirthdaySummary(widget.token);
      if (!mounted) return;

      List<BirthdayEntry> parseEntries(dynamic raw) {
        if (raw is List) {
          return raw
              .map((item) => BirthdayEntry.fromJson(item as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
        }
        return <BirthdayEntry>[];
      }

      DateTimeRange? parseRange(Map<String, dynamic>? json) {
        if (json == null) return null;
        try {
          final start = DateTime.parse((json['start'] ?? '') as String);
          final end = DateTime.parse((json['end'] ?? '') as String);
          return DateTimeRange(start: start, end: end);
        } catch (_) {
          return null;
        }
      }

      setState(() {
        _today = parseEntries(payload['today']);
        _thisWeek = parseEntries(payload['thisWeek']);
        _thisMonth = parseEntries(payload['thisMonth']);
        _generatedAt = DateTime.tryParse((payload['generatedAt'] ?? '') as String? ?? '');
        _weekRange = parseRange(payload['weekRange'] as Map<String, dynamic>?);
        _monthRange = parseRange(payload['monthRange'] as Map<String, dynamic>?);
        _loading = false;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleCelebrationState());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load birthday reminders right now. Pull to retry.';
      });
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final delay = nextMidnight.difference(now) + const Duration(minutes: 1);
    _midnightRefreshTimer = Timer(delay, () {
      if (!mounted) return;
      _loadSummary(showSpinner: false);
      _scheduleMidnightRefresh();
    });
  }

  void _handleCelebrationState() {
    if (!mounted) return;
    if (_today.isNotEmpty) {
      _startSpotlightAutoScroll();
      if (!_hasPlayedCelebration) {
        _hasPlayedCelebration = true;
        _playCelebrationTone();
        if (_confettiController.state != ConfettiControllerState.playing) {
          _confettiController.play();
        }
      } else if (_confettiController.state != ConfettiControllerState.playing) {
        _confettiController.play();
      }
    } else {
      _stopSpotlightAutoScroll();
      _confettiController.stop();
      _hasPlayedCelebration = false;
      _currentSpotlightIndex = 0;
    }
  }

  void _startSpotlightAutoScroll() {
    _spotlightTimer?.cancel();
    if (_today.length <= 1) {
      return;
    }
    _spotlightTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _today.isEmpty || !_spotlightController.hasClients) return;
      final nextIndex = (_currentSpotlightIndex + 1) % _today.length;
      _spotlightController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopSpotlightAutoScroll() {
    _spotlightTimer?.cancel();
    _spotlightTimer = null;
  }

  Future<void> _playCelebrationTone() async {
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      _cachedCelebrationTone ??= _buildCelebrationTone();
      await _audioPlayer!.play(BytesSource(_cachedCelebrationTone!));
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Uint8List _buildCelebrationTone({double frequency = 784.0, double seconds = 1.2, int sampleRate = 44100}) {
    final totalSamples = (sampleRate * seconds).round();
    final byteCount = totalSamples * 2;
    final ByteData data = ByteData(44 + byteCount);

    void writeString(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    data.setUint32(4, 36 + byteCount, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    data.setUint32(16, 16, Endian.little); // PCM chunk size
    data.setUint16(20, 1, Endian.little); // PCM format
    data.setUint16(22, 1, Endian.little); // channels
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    data.setUint16(32, 2, Endian.little); // block align
    data.setUint16(34, 16, Endian.little); // bits per sample
    writeString(36, 'data');
    data.setUint32(40, byteCount, Endian.little);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final env = i < sampleRate * 0.15
          ? i / (sampleRate * 0.15)
          : max(0, 1 - (i - sampleRate * 0.15) / (sampleRate * 0.8));
      final value = sin(2 * pi * frequency * t) * env * 0.4;
      data.setInt16(44 + (i * 2), (value * 32767).round(), Endian.little);
    }

    return data.buffer.asUint8List();
  }

  @override
  void dispose() {
    _midnightRefreshTimer?.cancel();
    _spotlightTimer?.cancel();
    _confettiController.dispose();
    _spotlightController.dispose();
    _audioPlayer?.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminSupportLayout(
      token: widget.token,
      pageTitle: 'Admin Support • Celebrants',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar:
            AdminSupportBottomNav(currentIndex: 2, token: widget.token),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: RefreshIndicator(
            onRefresh: () => _loadSummary(showSpinner: false),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isNarrow = width < 700;
                final crossAxisCount = width >= 1100
                    ? 3
                    : width >= 900
                        ? 2
                        : 1;

                final slivers = _buildSlivers(context, isNarrow, crossAxisCount);

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: slivers,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSlivers(
    BuildContext context,
    bool isNarrow,
    int crossAxisCount,
  ) {
    final theme = Theme.of(context);
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Birthday Celebrations',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay ahead of client and marketer birthdays happening this week and throughout the month.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            if (_generatedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last updated ${DateFormat.jm().format(_generatedAt!.toLocal())}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ];

    if (_loading && _today.isEmpty && _thisWeek.isEmpty && _thisMonth.isEmpty) {
      slivers.add(const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ));
      return slivers;
    }

    if (_error != null && _today.isEmpty && _thisWeek.isEmpty && _thisMonth.isEmpty) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorState(message: _error!, onRetry: () => _loadSummary()),
      ));
      return slivers;
    }

    if (_today.isNotEmpty) {
      slivers.add(_buildTodaySpotlight(context, isNarrow));
    }

    slivers.addAll([
      _buildHighlightSection(
        context,
        title: 'Birthdays this week',
        subtitle: _formatRange(_weekRange),
        icon: Icons.calendar_today_rounded,
        entries: _thisWeek,
      ),
      _buildHighlightSection(
        context,
        title: 'Birthdays this month',
        subtitle: _formatRange(_monthRange),
        icon: Icons.event_available_rounded,
        entries: _thisMonth,
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.cake_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Today\'s Celebrants',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${_today.length} celebrating',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    ]);

    if (_error != null) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _InlineErrorBanner(message: _error!, onRetry: () => _loadSummary()),
        ),
      ));
    }

    if (_today.isEmpty) {
      slivers.add(const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No birthdays today.')),
      ));
    } else {
      if (crossAxisCount == 1) {
        slivers.add(SliverList.separated(
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _BirthdayCard(
              entry: _today[index],
              compact: isNarrow,
            ),
          ),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: _today.length,
        ));
      } else {
        slivers.add(SliverPadding(
          padding: const EdgeInsets.only(bottom: 32),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: isNarrow ? 1.05 : 1.1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _BirthdayCard(
                entry: _today[index],
                compact: isNarrow,
              ),
              childCount: _today.length,
            ),
          ),
        ));
      }
    }

    return slivers;
  }

  Widget _buildTodaySpotlight(BuildContext context, bool isNarrow) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final textScale = media.textScaleFactor;
    final size = media.size;
    final bool needsTallCarousel = textScale > 1.1;
    final bool isShortViewport = size.height < 740;
    double carouselHeight = isNarrow ? 272 : 232;
    if (isNarrow) {
      if (needsTallCarousel) {
        carouselHeight += 40;
      }
      if (isShortViewport) {
        carouselHeight += 24;
      }
    } else if (needsTallCarousel) {
      carouselHeight += 24;
    }

    final spotlightBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.celebration, color: Colors.white.withOpacity(0.92)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Today's Celebrants",
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_today.length > 1)
              Text(
                '${_currentSpotlightIndex + 1}/${_today.length}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: carouselHeight,
          child: PageView.builder(
            controller: _spotlightController,
            itemCount: _today.length,
            onPageChanged: (index) {
              if (!mounted) return;
              setState(() {
                _currentSpotlightIndex = index;
              });
            },
            itemBuilder: (context, index) => _CelebrantHeroCard(entry: _today[index]),
          ),
        ),
        const SizedBox(height: 16),
        _buildSpotlightIndicators(),
      ],
    );

    return SliverToBoxAdapter(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _today.isEmpty
            ? const SizedBox.shrink()
            : Stack(
                key: ValueKey<int>(_today.length),
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 28),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.18),
                          blurRadius: 26,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _backgroundShift,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: spotlightBody,
                      ),
                      builder: (context, child) {
                        final t = _backgroundShift.value;
                        final gradient = LinearGradient(
                          begin: Alignment(-1 + 2 * t, -1),
                          end: Alignment(1 - 2 * t, 1),
                          colors: [
                            Color.lerp(const Color(0xFFFF5F6D), const Color(0xFFFF9966), t)!,
                            Color.lerp(const Color(0xFFFFF6B7), const Color(0xFFFFD56F), 1 - t)!,
                            Color.lerp(const Color(0xFF70E1F5), const Color(0xFFA8FF78), t)!,
                          ],
                        );

                        return DecoratedBox(
                          position: DecorationPosition.background,
                          decoration: BoxDecoration(gradient: gradient),
                          child: Stack(
                            fit: StackFit.loose,
                            children: [
                              CustomPaint(
                                painter: _CelebrationGlowPainter(progress: t),
                              ),
                              child!,
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        emissionFrequency: 0.05,
                        numberOfParticles: 25,
                        maxBlastForce: 20,
                        minBlastForce: 5,
                        gravity: 0.08,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSpotlightIndicators() {
    if (_today.length <= 1) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_today.length, (index) {
        final isActive = index == _currentSpotlightIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 22 : 10,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isActive ? 0.95 : 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }

  Widget _buildHighlightSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<BirthdayEntry> entries,
    String? subtitle,
  }) {
    if (entries.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entries.length}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) => _BirthdayHighlightCard(entry: entries[index]),
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemCount: entries.length,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String? _formatRange(DateTimeRange? range) {
    if (range == null) return null;
    final formatter = DateFormat('EEE, MMM d');
    final start = formatter.format(range.start.toLocal());
    final end = formatter.format(range.end.toLocal());
    return '$start – $end';
  }
}

class _BirthdayCard extends StatelessWidget {
  final BirthdayEntry entry;
  final bool compact;

  const _BirthdayCard({required this.entry, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = entry.roleLabel;
    final subtitleParts = <String>[
      if (entry.rankLabel != roleLabel) entry.rankLabel,
      roleLabel,
      if (entry.location.isNotEmpty) entry.location,
    ];
    final subtitle = subtitleParts.join(' • ');
    final accent = _roleAccentColor(roleLabel);

    String daysLabel;
    if (entry.daysUntil == 0) {
      daysLabel = 'Today';
    } else if (entry.daysUntil == 1) {
      daysLabel = 'Tomorrow';
    } else if (entry.daysUntil > 1) {
      daysLabel = 'In ${entry.daysUntil} days';
    } else {
      daysLabel = 'Passed';
    }

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [accent.withOpacity(0.28), accent.withOpacity(0.08)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CircleAvatar(
                  radius: compact ? 22 : 26,
                  backgroundColor: Colors.transparent,
                  backgroundImage: entry.avatarImage,
                  child: entry.avatarUrl.isEmpty
                      ? Text(
                          entry.initials,
                          style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        daysLabel,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 18),
          _InfoRow(
            icon: Icons.workspace_premium_outlined,
            label: 'Rank',
            value: entry.rankLabel,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: entry.role.toLowerCase() == 'client'
                ? Icons.home_work_outlined
                : Icons.workspace_premium,
            label: entry.role.toLowerCase() == 'client'
                ? 'Properties Owned'
                : 'Achievement',
            value: entry.role.toLowerCase() == 'client'
                ? entry.propertiesOwnedDisplay
                : entry.rankLabel,
          ),
          if (entry.addressDisplay.isNotEmpty && entry.role.toLowerCase() == 'client') ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Residential Address',
              value: entry.addressDisplay,
            ),
          ] else if (entry.location.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.place_outlined,
              label: 'Primary Location',
              value: entry.location,
            ),
          ],
        ],
      ),
    );
  }
}

class _BirthdayHighlightCard extends StatelessWidget {
  final BirthdayEntry entry;

  const _BirthdayHighlightCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateTime? birthday = entry.birthdayDate;
    final headline = birthday != null ? DateFormat('EEEE, MMMM d').format(birthday.toLocal()) : 'Birthday';
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool tightHeight = constraints.maxHeight < 180;
        final bool ultraTight = constraints.maxHeight < 150;
        final double avatarRadius = ultraTight ? 18 : (tightHeight ? 20 : 22);
        final double padding = tightHeight ? 14 : 16;
        final double wrapSpacing = tightHeight ? 8 : 12;

        return Container(
          width: tightHeight ? 240 : 260,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary.withOpacity(0.25), Colors.white.withOpacity(0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: Colors.transparent,
                      backgroundImage: entry.avatarImage,
                      child: entry.avatarUrl.isEmpty
                          ? Text(
                              entry.initials,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.rankLabel,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!tightHeight) const Spacer(),
              SizedBox(height: tightHeight ? 8 : 12),
              Text(
                headline,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                entry.daysUntil == 0
                    ? 'Today'
                    : entry.daysUntil == 1
                        ? 'Tomorrow'
                        : 'In ${entry.daysUntil} days',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
              SizedBox(height: tightHeight ? 10 : 16),
              if (!tightHeight) Divider(color: Colors.grey.shade200, height: 1),
              if (!tightHeight) SizedBox(height: tightHeight ? 10 : 16),
              Flexible(
                child: Wrap(
                  spacing: wrapSpacing,
                  runSpacing: 8,
                  children: [
                    _InfoChip(icon: Icons.workspace_premium_outlined, label: entry.rankDisplay),
                    if (entry.role.toLowerCase() == 'client')
                      _InfoChip(icon: Icons.home_outlined, label: entry.propertiesOwnedDisplay),
                    if (entry.role.toLowerCase() == 'marketer' && entry.hasMarketerMetrics)
                      _InfoChip(icon: Icons.people_outline, label: entry.assignedClientsDisplay),
                    if (entry.role.toLowerCase() == 'marketer' && entry.hasMarketerMetrics)
                      _InfoChip(icon: Icons.bar_chart_outlined, label: entry.yearlySalesDisplay),
                    if (entry.addressDisplay.isNotEmpty && entry.role.toLowerCase() == 'client')
                      _InfoChip(icon: Icons.location_on_outlined, label: entry.addressDisplay)
                    else if (entry.role.toLowerCase() == 'marketer' && entry.location.isNotEmpty && !tightHeight)
                      _InfoChip(icon: Icons.place_outlined, label: entry.location),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CelebrantHeroCard extends StatelessWidget {
  final BirthdayEntry entry;

  const _CelebrantHeroCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateTime? birthday = entry.birthdayDate;
    final headline = birthday != null ? DateFormat('EEEE, MMMM d').format(birthday.toLocal()) : 'Birthday';

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compactHeight = constraints.maxHeight < 320;
        final bool ultraCompact = constraints.maxHeight < 280;
        final double padding = compactHeight ? 16 : 18;
        final double avatarRadius = ultraCompact ? 24 : (compactHeight ? 26 : 28);
        final double horizontalGap = compactHeight ? 12 : 16;
        final double titleGap = compactHeight ? 10 : 14;
        final double metaGap = compactHeight ? 10 : 18;
        final double wrapSpacing = compactHeight ? 8 : 12;
        final double wrapRunSpacing = compactHeight ? 8 : 12;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [theme.colorScheme.primary.withOpacity(0.3), Colors.white.withOpacity(0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: Colors.transparent,
                      backgroundImage: entry.avatarImage,
                      child: entry.avatarUrl.isEmpty
                          ? Text(
                              entry.initials,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : null,
                    ),
                  ),
                  SizedBox(width: horizontalGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: compactHeight ? 4 : 6),
                        Text(
                          entry.roleLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: titleGap),
              Text(
                headline,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                entry.daysUntil == 0
                    ? 'Today'
                    : entry.daysUntil == 1
                        ? 'Celebrating tomorrow'
                        : 'In ${entry.daysUntil} days',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
              SizedBox(height: metaGap),
              Wrap(
                spacing: wrapSpacing,
                runSpacing: wrapRunSpacing,
                children: [
                  _InfoChip(icon: Icons.workspace_premium_outlined, label: entry.rankDisplay),
                  if (entry.role.toLowerCase() == 'client')
                    _InfoChip(icon: Icons.home_outlined, label: entry.propertiesOwnedDisplay),
                  if (entry.role.toLowerCase() == 'marketer' && entry.hasMarketerMetrics)
                    _InfoChip(icon: Icons.people_outline, label: entry.assignedClientsDisplay),
                  if (entry.role.toLowerCase() == 'marketer' && entry.hasMarketerMetrics)
                    _InfoChip(icon: Icons.bar_chart_outlined, label: entry.yearlySalesDisplay),
                  if (entry.addressDisplay.isNotEmpty && entry.role.toLowerCase() == 'client')
                    _InfoChip(icon: Icons.location_on_outlined, label: entry.addressDisplay),
                ],
              ),
              if (ultraCompact)
                const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 42, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red.shade700),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class BirthdayEntry {
  final int id;
  final String name;
  final String role;
  final String location;
  final String? email;
  final String? phone;
  final String birthday;
  final String originalBirthday;
  final int daysUntil;
  final String rank;
  final int? propertiesOwned;
  final String address;
  final String avatarUrl;
  final int? rankPosition;
  final int? assignedClients;
  final double? yearlySales;

  const BirthdayEntry({
    required this.id,
    required this.name,
    required this.role,
    required this.location,
    required this.email,
    required this.phone,
    required this.birthday,
    required this.originalBirthday,
    required this.daysUntil,
    required this.rank,
    required this.propertiesOwned,
    required this.address,
    required this.avatarUrl,
    required this.rankPosition,
    required this.assignedClients,
    required this.yearlySales,
  });

  factory BirthdayEntry.fromJson(Map<String, dynamic> json) {
    return BirthdayEntry(
      id: json['id'] as int,
      name: (json['name'] ?? 'Unnamed') as String,
      role: (json['role'] ?? 'member') as String,
      location: (json['location'] ?? '') as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      birthday: (json['birthday'] ?? '') as String,
      originalBirthday: (json['originalBirthday'] ?? '') as String,
      daysUntil: json['daysUntil'] is int
          ? json['daysUntil'] as int
          : int.tryParse('${json['daysUntil']}') ?? 0,
      rank: (json['rank'] as String?)?.trim() ?? '',
      propertiesOwned: json['propertiesOwned'] is num
          ? (json['propertiesOwned'] as num).round()
          : null,
      address: (json['address'] as String?)?.trim() ?? '',
      avatarUrl: (json['avatar'] as String?)?.trim() ?? '',
      rankPosition: json['rankPosition'] is num ? (json['rankPosition'] as num).round() : null,
      assignedClients: json['assignedClients'] is num ? (json['assignedClients'] as num).round() : null,
      yearlySales: json['yearlySales'] is num ? (json['yearlySales'] as num).toDouble() : null,
    );
  }

  String get roleLabel {
    switch (role.toLowerCase()) {
      case 'marketer':
        return 'Marketer';
      case 'client':
        return 'Client';
      default:
        return role.isNotEmpty ? role : 'Member';
    }
  }

  String get rankLabel => rank.isNotEmpty ? rank : roleLabel;

  String get rankDisplay {
    if (role.toLowerCase() != 'marketer') {
      return rankLabel;
    }
    final position = rankPosition;
    if (rankLabel.isNotEmpty && rankLabel != roleLabel) {
      return rankLabel;
    }
    if (position == null || position <= 0) {
      return 'Affiliate Partner';
    }
    if (position <= 5) return 'Top 5 Marketer';
    if (position <= 10) return 'Top 10 Marketer';
    if (position <= 20) return 'Top 20 Marketer';
    if (position <= 50) return 'Top 50 Marketer';
    return 'Affiliate Partner';
  }

  bool get hasMarketerMetrics => role.toLowerCase() == 'marketer' && (assignedClients != null || yearlySales != null);

  String get assignedClientsDisplay {
    if (role.toLowerCase() != 'marketer') {
      return '';
    }
    final value = assignedClients ?? 0;
    final noun = value == 1 ? 'client' : 'clients';
    return '$value $noun';
  }

  String get yearlySalesDisplay {
    if (role.toLowerCase() != 'marketer') {
      return '';
    }
    final sales = yearlySales ?? 0;
    if (sales <= 0) {
      return 'No sales yet this year';
    }
    final formatter = NumberFormat.compactCurrency(symbol: '₦');
    return '${formatter.format(sales)} sales YTD';
  }

  DateTime? get birthdayDate {
    try {
      return DateTime.parse(birthday);
    } catch (_) {
      return null;
    }
  }

  String get propertiesOwnedDisplay {
    if (propertiesOwned == null) {
      return role.toLowerCase() == 'client' ? 'No properties recorded yet' : '—';
    }
    final count = max(0, propertiesOwned!);
    if (count == 0) {
      return 'No properties recorded yet';
    }
    final noun = count == 1 ? 'property' : 'properties';
    return '$count $noun owned';
  }

  String get addressDisplay {
    if (address.isNotEmpty) {
      return address;
    }
    if (location.isNotEmpty) {
      return location;
    }
    return '';
  }

  ImageProvider get avatarImage {
    final source = avatarUrl;
    if (source.isNotEmpty) {
      if (source.startsWith('asset://')) {
        return AssetImage(source.replaceFirst('asset://', ''));
      }
      return NetworkImage(source);
    }
    return const AssetImage('assets/avater.webp');
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    return (parts.first.isNotEmpty ? parts.first[0] : '') +
        (parts.last.isNotEmpty ? parts.last[0] : '');
  }
}

Color _roleAccentColor(String roleLabel) {
  switch (roleLabel.toLowerCase()) {
    case 'marketer':
      return const Color(0xFF2D9CDB);
    case 'client':
      return const Color(0xFF27AE60);
    default:
      return const Color(0xFFF2994A);
  }
}
