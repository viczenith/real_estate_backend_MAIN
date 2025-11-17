import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:real_estate_app/shared/app_side.dart';
import 'package:real_estate_app/shared/app_layout.dart';
import 'package:real_estate_app/marketer/marketer_bottom_nav.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:fl_chart/fl_chart.dart';

class ChartData {
  final String time;
  final double sales;
  final double revenue;
  final double customers;

  ChartData({
    required this.time,
    required this.sales,
    required this.revenue,
    required this.customers,
  });
}

class MarketerDashboard extends StatefulWidget {
  final String token;
  final int? marketerId;
  const MarketerDashboard({required this.token, this.marketerId, super.key});

  @override
  _MarketerDashboardState createState() => _MarketerDashboardState();
}

class _MarketerDashboardState extends State<MarketerDashboard> 
    with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _chartLoading = false;
  String? _error;
  String? _chartError;

  // summary
  int totalTransactions = 0;
  int totalEstatesSold = 0;
  int numberClients = 0;

  // chart
  List<ChartData> chartData = [];
  String activeRange = 'weekly';
  final List<String> availableRanges = ['weekly', 'monthly', 'yearly', 'alltime'];

  Map<String, dynamic>? weeklyBlock;
  Map<String, dynamic>? monthlyBlock;
  Map<String, dynamic>? yearlyBlock;
  Map<String, dynamic>? alltimeBlock;

  // Animation controllers
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  
  // For chart animations
  late final AnimationController _chartAnimationController;
  late final Animation<double> _chartAnimation;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for live indicator
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 2)
    )..repeat(reverse: true);
    
    // Fade animation for content
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    // Chart animation
    _chartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _chartAnimation = CurvedAnimation(
      parent: _chartAnimationController,
      curve: Curves.easeOutCubic,
    );
    
    _loadDashboard().then((_) {
      _fadeController.forward();
      _chartAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _chartAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await _api.fetchMarketerDashboard(
        token: widget.token, 
        marketerId: widget.marketerId
      );
      final summary = payload['summary'] as Map<String, dynamic>? ?? {};
      setState(() {
        totalTransactions = (summary['total_transactions'] ?? 0) as int;
        totalEstatesSold = (summary['total_estates_sold'] ?? 0) as int;
        numberClients = (summary['number_clients'] ?? 0) as int;

        weeklyBlock = payload['weekly'] as Map<String, dynamic>?;
        monthlyBlock = payload['monthly'] as Map<String, dynamic>?;
        yearlyBlock = payload['yearly'] as Map<String, dynamic>?;
        alltimeBlock = payload['alltime'] as Map<String, dynamic>?;
      });
      await _loadChartRange(activeRange, useCached: true);
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

  Future<void> _loadChartRange(String range, {bool useCached = false}) async {
    setState(() {
      _chartLoading = true;
      _chartError = null;
      _chartAnimationController.reset();
    });
    try {
      Map<String, dynamic>? block;
      if (useCached) {
        switch (range) {
          case 'weekly':
            block = weeklyBlock;
            break;
          case 'monthly':
            block = monthlyBlock;
            break;
          case 'yearly':
            block = yearlyBlock;
            break;
          case 'alltime':
            block = alltimeBlock;
            break;
        }
      }
      if (block == null) {
        block = await _api.fetchMarketerChartRange(
          token: widget.token, 
          range: range, 
          marketerId: widget.marketerId
        );
      }
      final parsed = _parseChartBlockToChartData(block);
      setState(() {
        chartData = parsed;
        activeRange = range;
      });
      _chartAnimationController.forward();
    } catch (e) {
      setState(() {
        _chartError = e.toString();
      });
    } finally {
      setState(() {
        _chartLoading = false;
      });
    }
  }

  List<ChartData> _parseChartBlockToChartData(Map<String, dynamic> block) {
    final labels = (block['labels'] as List<dynamic>?)?.map((e) => e?.toString() ?? '').toList() ?? <String>[];
    final tx = (block['tx'] as List<dynamic>?) ?? <dynamic>[];
    final est = (block['est'] as List<dynamic>?) ?? <dynamic>[];
    final cli = (block['cli'] as List<dynamic>?) ?? <dynamic>[];

    final n = labels.length;
    final out = <ChartData>[];
    for (var i = 0; i < n; i++) {
      final time = labels[i];
      final sales = _toDoubleSafe(i < tx.length ? tx[i] : 0);
      final revenue = _toDoubleSafe(i < est.length ? est[i] : 0);
      final customers = _toDoubleSafe(i < cli.length ? cli[i] : 0);
      out.add(ChartData(time: time, sales: sales, revenue: revenue, customers: customers));
    }
    return out;
  }

  double _toDoubleSafe(dynamic v) {
    if (v == null) return 0.0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is String) {
      final cleaned = v.replaceAll(',', '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    if (v is num) return v.toDouble();
    return 0.0;
  }

  double _computeChartMaxY() {
    if (chartData.isEmpty) return 10.0;
    final maxVal = chartData
        .map((c) => [c.sales, c.revenue, c.customers].reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);
    final buffer = max(10.0, maxVal * 0.12);
    return (maxVal + buffer).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      pageTitle: 'Dashboard',
      token: widget.token,
      side: AppSide.marketer,
      child: Builder(
        builder: (layoutContext) {
          final theme = Theme.of(layoutContext);
          final isDark = theme.brightness == Brightness.dark;
          final controller = AppLayout.maybeOf(layoutContext);

          Widget buildBottomNav() {
            if (controller == null) {
              return MarketerBottomNav(
                currentIndex: 0,
                token: widget.token,
                chatBadge: 0,
              );
            }

            return ValueListenableBuilder<Map<String, int>>(
              valueListenable: controller.countsNotifier,
              builder: (context, counts, _) {
                final badge = counts['messages'] ?? controller.unreadMessages;
                return MarketerBottomNav(
                  currentIndex: 0,
                  token: widget.token,
                  chatBadge: badge,
                );
              },
            );
          }

          return Scaffold(
            backgroundColor: isDark
                ? Colors.grey.shade900.withOpacity(0.98)
                : Colors.grey.shade50,
            bottomNavigationBar: buildBottomNav(),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: _loadDashboard,
                color: theme.colorScheme.primary,
                backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 18),
                        child: IntrinsicHeight(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(context),
                                const SizedBox(height: 24),
                                if (_loading)
                                  _buildLoadingSkeleton(context)
                                else if (_error != null)
                                  _buildErrorCard(_error!, onRetry: _loadDashboard)
                                else ...[
                                  _buildSummarySection(constraints),
                                  const SizedBox(height: 28),
                                  _buildChartSection(constraints),
                                  const SizedBox(height: 28),
                                ],
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overview', 
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                  fontSize: 24
                )
              ),
              const SizedBox(height: 6),
              Text(
                'Home / Dashboard', 
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 13
                )
              ),
            ],
          ),
        ),
        ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1.04).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight
              ),
              borderRadius: BorderRadius.circular(20), 
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3)
                )
              ]
            ),
            child: Row(
              children: [
                Icon(Icons.show_chart, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Live Data', 
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.w600,
                    fontSize: 13
                  )
                ),
              ]
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSummarySection(BoxConstraints constraints) {
    final isNarrow = constraints.maxWidth < 720;
    final cardWidth = isNarrow ? constraints.maxWidth : (constraints.maxWidth - 32) / 3;
    
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _animatedSummaryCard(
          icon: Icons.receipt_long, 
          title: 'Total Transactions', 
          value: totalTransactions.toString(), 
          color: Colors.indigo, 
          width: cardWidth
        ),
        _animatedSummaryCard(
          icon: Icons.business, 
          title: 'Total Estates Sold', 
          value: totalEstatesSold.toString(), 
          color: Colors.teal, 
          width: cardWidth
        ),
        _animatedSummaryCard(
          icon: Icons.people_alt, 
          title: 'Number of Clients', 
          value: numberClients.toString(), 
          color: Colors.deepOrange, 
          width: cardWidth
        ),
      ],
    );
  }

  Widget _animatedSummaryCard({
    required IconData icon, 
    required String title, 
    required String value, 
    required Color color, 
    required double width
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 20),
            child: Transform.scale(scale: 0.95 + (t * 0.05), child: child),
          ),
        );
      },
      child: _summaryCard(
        icon: icon, 
        title: title, 
        value: value, 
        color: color, 
        width: width
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon, 
    required String title, 
    required String value, 
    required Color color, 
    required double width
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: max(280, width),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? Colors.grey.shade800 : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isDark 
                 ? Colors.black.withOpacity(0.6)
                 : Colors.grey.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5)
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Text(
                      value, 
                      key: ValueKey(value), 
                      style: TextStyle(
                        fontSize: 26, 
                        fontWeight: FontWeight.w800, 
                        color: color,
                        shadows: [
                          Shadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 2)
                          )
                        ]
                      )
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title, 
                    textAlign: TextAlign.right, 
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                      fontSize: 14
                    )
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(BoxConstraints constraints) {
    final isNarrow = constraints.maxWidth < 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Title with ellipsis so it doesn't expand the row.
    final titleWidget = Text(
      'Performance Analytics',
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.grey.shade800,
        fontSize: 20,
      ),
    );

    // Chips placed in a horizontal scroll view (prevents overflow).
    final chipsWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      // Use SingleChildScrollView -> Row so chips can scroll horizontally when there's no room.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: availableRanges.map((r) {
            final active = r == activeRange;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: ConstrainedBox(
                  // Prevent excessively long chip labels from forcing width; they will ellipsize.
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    _labelFromRange(r),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                selected: active,
                onSelected: (_) => _onRangeSelected(r),
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.transparent,
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: StadiumBorder(
                  side: BorderSide(
                    color: active
                        ? Colors.transparent
                        : isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Responsive layout: chips on new row for narrow screens, chips on the right for wide screens.
        if (isNarrow) ...[
          titleWidget,
          const SizedBox(height: 10),
          chipsWidget,
        ] else
          Row(
            children: [
              // Give title remaining space but allow it to ellipsize if needed.
              Expanded(child: titleWidget),
              const SizedBox(width: 12),
              // Make the chips take only as much space as they need and scroll if longer.
              Flexible(child: chipsWidget),
            ],
          ),
        const SizedBox(height: 16),
        // ... rest of your original logic (loading/error/chart) unchanged
        if (_chartLoading)
          Container(
            height: isNarrow ? 300 : 380,
            decoration: _cardDecoration(),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          )
        else if (_chartError != null)
          _buildErrorCard(_chartError!, onRetry: () => _loadChartRange(activeRange, useCached: false))
        else
          _buildAdvancedLineChart(isNarrow: isNarrow, maxWidth: constraints.maxWidth),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return BoxDecoration(
      color: isDark ? Colors.grey.shade800 : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: isDark 
            ? Colors.black.withOpacity(0.5)
            : Colors.grey.withOpacity(0.2),
          blurRadius: 15,
          offset: const Offset(0, 5)
        )
      ]
    );
  }

  Widget _buildAdvancedLineChart({required bool isNarrow, required double maxWidth}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (chartData.isEmpty) {
      return Container(
        height: isNarrow ? 280 : 360, 
        decoration: _cardDecoration(), 
        child: Center(
          child: Text(
            'No data for selected range', 
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              fontSize: 16
            )
          )
        )
      );
    }

    final spotsSales = <FlSpot>[];
    final spotsEst = <FlSpot>[];
    final spotsCli = <FlSpot>[];
    for (var i = 0; i < chartData.length; i++) {
      spotsSales.add(FlSpot(i.toDouble(), chartData[i].sales));
      spotsEst.add(FlSpot(i.toDouble(), chartData[i].revenue));
      spotsCli.add(FlSpot(i.toDouble(), chartData[i].customers));
    }

    final maxY = _computeChartMaxY();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      height: isNarrow ? 300 : 380,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _legendDot(label: 'Transactions', color: Colors.deepPurple),
              const SizedBox(width: 16),
              _legendDot(label: 'Estates Sold', color: Colors.teal),
              const SizedBox(width: 16),
              _legendDot(label: 'New Clients', color: Colors.orange),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: max(1, (maxY / 5).floorToDouble()),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                        strokeWidth: 1,
                        dashArray: [4],
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: max(1, (maxY / 5).floorToDouble()),
                        reservedSize: 42,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.w500
                              )
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= chartData.length) return const SizedBox.shrink();
                          final label = chartData[idx].time;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight: FontWeight.w500
                              )
                            ),
                          );
                        },
                        interval: chartData.length > 12 ? (chartData.length / 6).floorToDouble() : 1,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  minX: 0,
                  maxX: (chartData.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((ts) {
                          final idx = ts.x.toInt().clamp(0, chartData.length - 1);
                          final label = chartData[idx].time;
                          final y = ts.y.toInt();
                          final seriesName = ts.barIndex == 0 
                            ? 'Transactions' 
                            : ts.barIndex == 1 
                              ? 'Estates' 
                              : 'Clients';

                          Color textColor = isDark ? Colors.white : Colors.black;
                          try {
                            final grad = ts.bar.gradient;
                            if (grad is LinearGradient && grad.colors.isNotEmpty) {
                              textColor = grad.colors.first.computeLuminance() > 0.5 
                                ? Colors.black 
                                : Colors.white;
                            } else if (ts.bar.color != null) {
                              textColor = ts.bar.color!.computeLuminance() > 0.5 
                                ? Colors.black 
                                : Colors.white;
                            }
                          } catch (_) {
                            textColor = isDark ? Colors.white : Colors.black;
                          }

                          return LineTooltipItem(
                            '$seriesName: $y\n$label', 
                            TextStyle(
                              color: textColor, 
                              fontWeight: FontWeight.bold,
                              fontSize: 13
                            )
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spotsSales,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade400,
                          Colors.deepPurple.shade200,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      barWidth: 4,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.deepPurple.shade400,
                            strokeWidth: 2,
                            strokeColor: isDark ? Colors.black : Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.withOpacity(0.25),
                            Colors.deepPurple.withOpacity(0.05),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    LineChartBarData(
                      spots: spotsEst,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal.shade400,
                          Colors.teal.shade200,
                        ],
                      ),
                      barWidth: 4,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.teal.withOpacity(0.2),
                            Colors.teal.withOpacity(0.02),
                          ],
                        ),
                      ),
                    ),
                    LineChartBarData(
                      spots: spotsCli,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.orange.shade200,
                        ],
                      ),
                      barWidth: 4,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.withOpacity(0.2),
                            Colors.orange.withOpacity(0.02),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _legendDot({required String label, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          width: 12, 
          height: 12, 
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 6,
                offset: const Offset(0, 2)
              )
            ]
          )
        ),
        const SizedBox(width: 8),
        Text(
          label, 
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700
          )
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Row(
          children: [
            _skeleton(width: 160, height: 18),
            const SizedBox(width: 8),
            _skeleton(width: 100, height: 18),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16, 
          runSpacing: 16, 
          children: List.generate(3, (i) => _skeletonCard())
        ),
        const SizedBox(height: 24),
        _skeleton(height: 320),
      ],
    );
  }

  Widget _skeleton({double? width, double height = 14}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: isDark 
              ? Colors.grey.shade700.withOpacity(0.5 + 0.1 * sin(_pulseController.value * pi))
              : Colors.grey.shade200.withOpacity(0.5 + 0.1 * sin(_pulseController.value * pi)),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      },
    );
  }

  Widget _skeletonCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 320,
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark 
              ? Colors.black.withOpacity(0.4)
              : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          _skeleton(width: 80, height: 18),
          const SizedBox(height: 16),
          _skeleton(height: 26),
          const Spacer(),
          Row(children: [_skeleton(width: 140, height: 14)])
        ]
      ),
    );
  }

  Widget _buildErrorCard(String message, {required FutureOr<void> Function() onRetry}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message, 
              style: TextStyle(color: Colors.red.shade800)
            ),
          ),
          TextButton.icon(
            onPressed: () => onRetry(), 
            icon: Icon(Icons.refresh, color: Colors.red.shade700),
            label: Text(
              'Retry', 
              style: TextStyle(color: Colors.red.shade700)
            ),
          ),
        ],
      ),
    );
  }

  void _onRangeSelected(String range) {
    if (range == activeRange) return;
    _loadChartRange(range, useCached: true);
  }

  String _labelFromRange(String r) {
    switch (r) {
      case 'weekly':
        return 'Week';
      case 'monthly':
        return 'Month';
      case 'yearly':
        return 'Year';
      case 'alltime':
        return 'All-Time';
    }
    return r;
  }

}