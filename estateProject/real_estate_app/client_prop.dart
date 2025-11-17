// import 'package:flutter/material.dart';
// import 'package:real_estate_app/shared/app_side.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:real_estate_app/shared/app_layout.dart';
// import 'package:real_estate_app/client/client_bottom_nav.dart';

// class ChartData {
//   final String time;
//   final double sales;
//   final double revenue;
//   final double customers;

//   ChartData({
//     required this.time,
//     required this.sales,
//     required this.revenue,
//     required this.customers,
//   });
// }

// class ClientDashboard extends StatefulWidget {
//   final String token;
//   const ClientDashboard({required this.token, super.key});

//   @override
//   _ClientDashboardState createState() => _ClientDashboardState();
// }

// class _ClientDashboardState extends State<ClientDashboard> {
//   // Sample data for Syncfusion chart
//   final List<ChartData> salesData = [
//     ChartData(time: '00:00', sales: 40, revenue: 50, customers: 30),
//     ChartData(time: '03:00', sales: 55, revenue: 60, customers: 20),
//     ChartData(time: '06:00', sales: 35, revenue: 40, customers: 50),
//     ChartData(time: '09:00', sales: 60, revenue: 70, customers: 40),
//     ChartData(time: '12:00', sales: 45, revenue: 65, customers: 60),
//     ChartData(time: '15:00', sales: 70, revenue: 85, customers: 50),
//     ChartData(time: '18:00', sales: 55, revenue: 60, customers: 70),
//     ChartData(time: '21:00', sales: 80, revenue: 90, customers: 65),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return AppLayout(
//       pageTitle: 'Client Dashboard',
//       token: widget.token,
//       side: AppSide.client,
//       child: Scaffold(
//         backgroundColor: const Color(0xFFF7F7F7),
//         // Attach the beautiful bottom nav here
//         bottomNavigationBar: ClientBottomNav(
//           currentIndex: 0,
//           token: widget.token,
//           chatBadge: 1,
//         ),
//         body: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const SizedBox(height: 6),
//                 Text(
//                   "Client Dashboard",
//                   style: TextStyle(
//                       fontSize: 26,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87),
//                 ),
//                 const SizedBox(height: 5),
//                 Text("Home / Dashboard", style: TextStyle(color: Colors.grey)),
//                 const SizedBox(height: 20),

//                 // Summary Cards
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     dashboardCard(
//                         Icons.home, "Properties Purchased", "7", Colors.blue),
//                     dashboardCard(Icons.assignment_turned_in,
//                         "Fully Paid & Allocated", "5", Colors.green),
//                     dashboardCard(Icons.pending_actions, "Not Fully Paid", "2",
//                         Colors.orange),
//                   ],
//                 ),

//                 const SizedBox(height: 25),
//                 Text("Property Value Chart",
//                     style:
//                         TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 10),

//                 // Syncfusion Multi-Line Chart
//                 buildSyncfusionChart(),

//                 const SizedBox(height: 25),
//                 Text("News & Update",
//                     style:
//                         TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 10),

//                 // News items
//                 buildNewsItem(
//                   image: "assets/logo.png",
//                   heading: "Nihil blanditiis at in nihil autem",
//                   body:
//                       "Itaque suscipit suscipit recusandae harum perspiciatis. Quia enim eligendi sed ut harum explicabo delectus?",
//                   time: "2 hrs ago",
//                 ),
//                 buildNewsItem(
//                   image: "assets/logo.png",
//                   heading: "Quidem autem et impedit",
//                   body:
//                       "Illo nemo neque maiores vitae officiis cum eum. Rerum deleniti dicta doloribus temporibus asperiores.",
//                   time: "5 hrs ago",
//                 ),
//                 buildNewsItem(
//                   image: "assets/logo.png",
//                   heading: "Id quia et et maxime similique coaccati",
//                   body:
//                       "Fugiat esse fugit illum vero beatae suscipit accusamus. Odit ipsam aspernatur reiciendis.",
//                   time: "8 hrs ago",
//                 ),
//                 const SizedBox(height: 40),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // Dashboard Card Widget
//   Widget dashboardCard(IconData icon, String title, String value, Color color) {
//     return Expanded(
//       child: Container(
//         margin: const EdgeInsets.all(8),
//         padding: const EdgeInsets.all(18),
//         decoration: BoxDecoration(
//           color: const Color(0xFFF1F1F1),
//           borderRadius: BorderRadius.circular(15),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.15),
//               offset: const Offset(0, 4),
//               blurRadius: 6,
//             )
//           ],
//         ),
//         child: Column(
//           children: [
//             Icon(icon, size: 40, color: color),
//             const SizedBox(height: 10),
//             Text(value,
//                 style: TextStyle(
//                     fontSize: 24, fontWeight: FontWeight.bold, color: color)),
//             const SizedBox(height: 5),
//             Text(title,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                     color: Colors.black87, fontWeight: FontWeight.w600)),
//           ],
//         ),
//       ),
//     );
//   }

//   // Syncfusion Multi-Line Chart Widget
//   Widget buildSyncfusionChart() {
//     return Container(
//       height: 300,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(15),
//         boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
//       ),
//       padding: const EdgeInsets.all(15),
//       child: SfCartesianChart(
//         legend: Legend(isVisible: true),
//         tooltipBehavior: TooltipBehavior(enable: true),
//         primaryXAxis: CategoryAxis(),
//         primaryYAxis: NumericAxis(minimum: 0, maximum: 100, interval: 20),
//         series: <ChartSeries>[
//           // Sales Series
//           LineSeries<ChartData, String>(
//             name: "Sales",
//             dataSource: salesData,
//             xValueMapper: (ChartData data, _) => data.time,
//             yValueMapper: (ChartData data, _) => data.sales,
//             markerSettings: const MarkerSettings(isVisible: true),
//           ),
//           // Revenue Series
//           LineSeries<ChartData, String>(
//             name: "Revenue",
//             dataSource: salesData,
//             xValueMapper: (ChartData data, _) => data.time,
//             yValueMapper: (ChartData data, _) => data.revenue,
//             markerSettings: const MarkerSettings(isVisible: true),
//           ),
//           // Customers Series
//           LineSeries<ChartData, String>(
//             name: "Customers",
//             dataSource: salesData,
//             xValueMapper: (ChartData data, _) => data.time,
//             yValueMapper: (ChartData data, _) => data.customers,
//             markerSettings: const MarkerSettings(isVisible: true),
//           ),
//         ],
//       ),
//     );
//   }

//   // News Item Widget
//   Widget buildNewsItem({
//     required String image,
//     required String heading,
//     required String body,
//     required String time,
//   }) {
//     return InkWell(
//       onTap: () {},
//       child: Container(
//         margin: const EdgeInsets.only(bottom: 12),
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(15),
//           boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
//         ),
//         child: Row(
//           children: [
//             // Thumbnail Image
//             ClipRRect(
//               borderRadius: BorderRadius.circular(8),
//               child:
//                   Image.asset(image, width: 70, height: 70, fit: BoxFit.cover),
//             ),
//             const SizedBox(width: 12),
//             // News Text
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(heading,
//                       style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black87)),
//                   const SizedBox(height: 5),
//                   Text(
//                     body,
//                     style: TextStyle(fontSize: 14, color: Colors.grey[700]),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   const SizedBox(height: 8),
//                   Text(time,
//                       style: TextStyle(fontSize: 12, color: Colors.grey)),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
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

class _ClientDashboardState extends State<ClientDashboard> with TickerProviderStateMixin {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
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
  final PageController _promoPageController = PageController(viewportFraction: 0.92);
  int _currentPromoIndex = 0;

  final NumberFormat _ngnFmt = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _staggerAnim = CurvedAnimation(parent: _staggerController, curve: Curves.easeOutCubic);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _fetchDashboard();
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
    _promoCarouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
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
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await _api.getClientDashboardData(widget.token);
      // expected keys: total_properties, fully_paid_allocations, not_fully_paid_allocations, active_promotions, latest_value
      setState(() {
        _data = resp;
        _activePromos = List<Map<String, dynamic>>.from(resp['active_promotions'] ?? []);
        _latestValue = List<Map<String, dynamic>>.from(resp['latest_value'] ?? []);
      });
      _staggerController.forward();
      
      // Start the carousel after data is loaded
      if (_activePromos.isNotEmpty) {
        _startPromoCarousel();
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  // Filter + sort logic similar to Django's JS
  List<Map<String, dynamic>> _filteredPriceCards() {
    final q = _priceSearchCtr.text.trim().toLowerCase();
    List<Map<String, dynamic>> cards = List.from(_latestValue);

    if (_promoOnly) cards = cards.where((c) => c['promo'] != null).toList();
    if (q.isNotEmpty) {
      cards = cards.where((c) {
        final estate = (c['price']?['estate_name'] ?? '').toString().toLowerCase();
        final size = (c['plot_unit']?['size'] ?? '').toString().toLowerCase();
        return estate.contains(q) || size.contains(q);
      }).toList();
    }

    int cmpPercent(Map a) => ((a['percent_change'] ?? 0) as num).toInt();
    double curVal(Map a) => (a['current'] ?? 0).toDouble();

    cards.sort((a, b) {
      switch (_priceSort) {
        case 'biggest_up': return (b['percent_change'] ?? 0).compareTo(a['percent_change'] ?? 0);
        case 'biggest_down': return (a['percent_change'] ?? 0).compareTo(b['percent_change'] ?? 0);
        case 'highest_price': return curVal(b).compareTo(curVal(a));
        case 'promo_first':
          final ap = (b['promo'] != null ? 1 : 0) - (a['promo'] != null ? 1 : 0);
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
    } catch (e) { return v.toString(); }
  }

  Future<void> _openPromoDetail(Map<String, dynamic> promo) async {
    // push to PromotionDetailPage
    final id = (promo['id'] as num?)?.toInt();
    if (id == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PromotionDetailPage(token: widget.token, promoId: id)));
  }

  Future<void> _openPriceDetail(int id) async {
    showDialog(context: context, builder: (_) => PriceDetailDialog(api: _api, token: widget.token, priceHistoryId: id));
  }

  Widget _buildTopStats() {
    final total = (_data['total_properties'] ?? 0).toString();
    final fully = (_data['fully_paid_allocations'] ?? 0).toString();
    final notFully = (_data['not_fully_paid_allocations'] ?? 0).toString();

    Widget card(String title, String value, IconData icon, Color color) {
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)
              )
            ]
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12)
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color))
              ])
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth > 800;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
        child: wide ? Row(
          children: [
            Expanded(child: card('My Properties Purchased', total, Icons.shopping_cart, Colors.indigo)),
            const SizedBox(width: 12),
            Expanded(child: card('Fully Paid & Allocated', fully, Icons.account_balance_wallet, Colors.teal)),
            const SizedBox(width: 12),
            Expanded(child: card('Not Fully Paid', notFully, Icons.money_off, Colors.orange)),
          ],
        ) : Column(children: [
          card('My Properties Purchased', total, Icons.shopping_cart, Colors.indigo),
          const SizedBox(height: 12),
          card('Fully Paid & Allocated', fully, Icons.account_balance_wallet, Colors.teal),
          const SizedBox(height: 12),
          card('Not Fully Paid', notFully, Icons.money_off, Colors.orange)
        ]),
      );
    });
  }

  Widget _buildPromotionsCarousel() {
    if (_activePromos.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.local_offer, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text('No active promotions right now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Check back later or explore all estates.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
            ]
          )
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: PageView.builder(
        controller: _promoPageController,
        onPageChanged: (index) {
          setState(() {
            _currentPromoIndex = index;
          });
        },
        itemCount: _activePromos.length,
        itemBuilder: (ctx, i) {
          final promo = _activePromos[i];
          final estates = List.from(promo['estates'] ?? []);
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 400 + (i * 100)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, t, child) {
              return Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: 0.95 + (t * 0.05),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: GestureDetector(
                onTap: () => _openPromoDetail(promo),
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.deepPurple.shade50,
                          Colors.blue.shade50,
                        ]
                      )
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4)
                            )
                          ]
                        ),
                        child: const Icon(Icons.local_offer, size: 36, color: Colors.deepOrange),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              promo['name'] ?? 'Promotion',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              promo['description'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (var e in estates.take(3))
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      e['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.deepPurple.shade700,
                                        fontWeight: FontWeight.w600
                                      ),
                                    ),
                                  ),
                                if (estates.length > 3)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '+${estates.length - 3} more',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  )
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xffff7a7a), Color(0xffffb46b)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4)
                                )
                              ]
                            ),
                            child: Text(
                              '-${promo['discount'] ?? 0}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            promo['end'] ?? '',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        ],
                      )
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceExplorer() {
    final cards = _filteredPriceCards();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _priceSearchCtr,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search estate or size',
                  isDense: true,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade50,
                ),
                onChanged: (_) { setState(() {}); },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<String>(
                value: _priceSort,
                items: const [
                  DropdownMenuItem(value: 'newest', child: Text('Newest')),
                  DropdownMenuItem(value: 'biggest_up', child: Text('Largest increase')),
                  DropdownMenuItem(value: 'biggest_down', child: Text('Largest decrease')),
                  DropdownMenuItem(value: 'highest_price', child: Text('Highest price')),
                  DropdownMenuItem(value: 'promo_first', child: Text('Promo first'))
                ],
                onChanged: (v) {
                  if (v != null) setState(() { _priceSort = v; });
                },
                underline: const SizedBox(),
                borderRadius: BorderRadius.circular(12),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Promo only'),
              selected: _promoOnly,
              onSelected: (v) => setState(() { _promoOnly = v; }),
              checkmarkColor: Colors.white,
              selectedColor: Theme.of(context).colorScheme.primary,
            )
          ]),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${cards.length} updates', style: const TextStyle(color: Colors.grey)),
          ),
        ),

        const SizedBox(height: 8),

        // grid/list of cards - Fixed the duplication issue
        AnimatedBuilder(
          animation: _staggerAnim,
          builder: (context, _) {
            return LayoutBuilder(builder: (ctx, cons) {
              final cols = cons.maxWidth > 1000 ? 3 : (cons.maxWidth > 600 ? 2 : 1);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: cards.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    mainAxisExtent: 200
                  ),
                  itemBuilder: (ctx, i) {
                    final c = cards[i];
                    final promo = c['promo'];
                    final percent = c['percent_change'];
                    final up = (percent ?? 0) >= 0;
                    
                    return Opacity(
                      opacity: 1.0, // Removed the opacity animation that was causing issues
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _staggerController,
                            curve: Interval(0.1 * i, 1.0, curve: Curves.easeOutBack)
                          )
                        ),
                        child: _buildPriceCard(c, promo, up, percent),
                      ),
                    );
                  },
                ),
              );
            });
          },
        ),
        const SizedBox(height: 12)
      ],
    );
  }

  Widget _buildPriceCard(Map<String, dynamic> c, dynamic promo, bool up, dynamic percent) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openPriceDetail((c['id'] as num).toInt()),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                (up ? Colors.green.shade50 : Colors.red.shade50).withOpacity(0.4),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['price']?['estate_name'] ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          c['plot_unit']?['size'] ?? '-',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        )
                      ],
                    ),
                  ),
                  if (promo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffff7a7a), Color(0xffffb46b)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PROMO -${promo['discount']}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10
                        ),
                      ),
                    )
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (promo != null && c['promo_price'] != null)
                        Text(
                          _formatNGN(c['promo_price']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.deepOrange
                          ),
                        ),
                      if (promo != null && c['promo_price'] != null)
                        Text(
                          _formatNGN(c['current']),
                          style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 12
                          ),
                        )
                      else
                        Text(
                          _formatNGN(c['current']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Colors.green
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Prev: ${_formatNGN(c['previous'])}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      )
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: up ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: up ? Colors.green : Colors.red,
                            width: 1
                          )
                        ),
                        child: Text(
                          '${(percent ?? 0).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: up ? Colors.green.shade800 : Colors.red.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 14
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          c['effective'] ?? '-',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      )
                    ],
                  )
                ],
              ),
              
              const SizedBox(height: 12),
              
              if (c['notes'] != null && c['notes'].toString().isNotEmpty)
                Text(
                  c['notes'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AppLayout(
      pageTitle: 'Client Dashboard',
      token: widget.token,
      side: AppSide.client,
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
        bottomNavigationBar: ClientBottomNav(currentIndex: 0, token: widget.token, chatBadge: 0),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchDashboard,
            color: Theme.of(context).colorScheme.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(children: [
                // header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Client Dashboard',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 28,
                              color: isDark ? Colors.white : Colors.grey.shade800
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Home / Dashboard',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          )
                        ],
                      ),
                    ),
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.96, end: 1.04).animate(
                        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _fetchDashboard,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    )
                  ]),
                ),

                if (_loading) 
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
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
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
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
                                  MaterialPageRoute(builder: (_) => PromotionsListPage(token: widget.token))
                                ),
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
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => PromotionsListPage(token: widget.token))
                                ),
                                icon: const Icon(Icons.local_offer_outlined),
                                label: const Text('Promotions'),
                              )
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
  final ApiService api;
  final String token;
  final int priceHistoryId;

  const PriceDetailDialog({Key? key, required this.api, required this.token, required this.priceHistoryId}) : super(key: key);

  @override
  _PriceDetailDialogState createState() => _PriceDetailDialogState();
}

class _PriceDetailDialogState extends State<PriceDetailDialog> with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await widget.api.getPriceUpdateById(widget.priceHistoryId, token: widget.token);
      setState(() { _data = resp; });
      _animationController.forward();
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally { setState(() { _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        )
                      ],
                    )
                  : ScaleTransition(
                      scale: _animation,
                      child: _buildContent(),
                    )),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_data == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Price Update Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            )
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _data!['estate_name'] ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Recorded: ${_data!['recorded_at'] ?? '-'}',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildDetailRow('Previous', _format(_data!['previous'])),
              const SizedBox(height: 8),
              _buildDetailRow('Current', _format(_data!['current'])),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Change',
                '${(_data!['percent_change'] ?? '-').toString()}%',
                isPercent: true,
                percent: (_data!['percent_change'] as num?)?.toDouble(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Notes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _data!['notes'] ?? '—',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        )
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isPercent = false, double? percent}) {
    Color color = Colors.black;
    if (isPercent && percent != null) {
      color = percent >= 0 ? Colors.green : Colors.red;
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: color,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _format(dynamic v) {
    if (v == null) return '—';
    try {
      final numVal = (v is num) ? v : double.parse(v.toString());
      return NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0).format(numVal);
    } catch (_) { return v.toString(); }
  }
}

// ---------------------------
// Promotions List Page
// ---------------------------
class PromotionsListPage extends StatefulWidget {
  final String token;
  const PromotionsListPage({Key? key, required this.token}) : super(key: key);

  @override
  _PromotionsListPageState createState() => _PromotionsListPageState();
}

class _PromotionsListPageState extends State<PromotionsListPage> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  List<dynamic> _active = [];
  Map<String, dynamic>? _paginated;
  int _page = 1;
  String _filter = 'all';
  String _q = '';
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await _api.listPromotions(token: widget.token, filter: _filter, q: _q, page: page);
      setState(() {
        _active = resp['active_promotions'] ?? [];
        _paginated = resp['promotions'];
        _page = page;
      });
      _animationController.forward();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (_active.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Currently active',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                              ),
                              const SizedBox(height: 12),
                              ..._active.map((p) {
                                return FadeTransition(
                                  opacity: _animationController,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(-1, 0),
                                      end: Offset.zero,
                                    ).animate(CurvedAnimation(
                                      parent: _animationController,
                                      curve: Curves.easeOutCubic,
                                    )),
                                    child: Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(16),
                                        leading: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.deepOrange.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.local_offer,
                                            color: Colors.deepOrange,
                                          ),
                                        ),
                                        title: Text(
                                          p['name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        subtitle: Text(
                                          p['description'] ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        trailing: Chip(
                                          label: Text(
                                            '-${p['discount']}%',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          backgroundColor: Colors.deepOrange,
                                        ),
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PromotionDetailPage(
                                              token: widget.token,
                                              promoId: (p['id'] as num).toInt(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        Expanded(
                          child: _buildPromotionsList(),
                        )
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildPromotionsList() {
    if (_paginated == null) return const SizedBox.shrink();
    final results = List.from(_paginated!['results'] ?? []);
    final pageNum = _paginated!['page'] ?? _page;
    final totalPages = _paginated!['total_pages'] ??
        (_paginated!['count'] != null
            ? ((_paginated!['count'] as int) / 12).ceil()
            : 1);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (ctx, i) {
              final p = results[i];
              return FadeTransition(
                opacity: Tween<double>(begin: 0, end: 1).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(0.1 * i, 1.0, curve: Curves.easeIn),
                  ),
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: Interval(0.1 * i, 1.0, curve: Curves.easeOut),
                    ),
                  ),
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_offer_outlined,
                          color: Colors.blue,
                        ),
                      ),
                      title: Text(
                        p['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        (p['description'] ?? '').toString().truncate(120),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Chip(
                        label: Text(
                          '-${p['discount']}%',
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.blue,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PromotionDetailPage(
                            token: widget.token,
                            promoId: (p['id'] as num).toInt(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: pageNum > 1
                  ? () {
                      _load(page: pageNum - 1);
                    }
                  : null,
            ),
            Text('Page $pageNum of $totalPages'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: pageNum < totalPages
                  ? () {
                      _load(page: pageNum + 1);
                    }
                  : null,
            ),
          ],
        ),
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
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _api.getPromotionDetail(widget.promoId, token: widget.token);
      setState(() => _promo = resp);
      _animationController.forward();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotion details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: FadeTransition(
                      opacity: _animationController,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _animationController,
                          curve: Curves.easeOutCubic,
                        )),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _promo!["name"] ?? "",
                                            style: const TextStyle(
                                                fontSize: 20, fontWeight: FontWeight.w800),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Valid: ${_promo!["start"] ?? ""} → ${_promo!["end"] ?? ""}',
                                            style: const TextStyle(color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        '-${_promo!["discount"]}%',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.deepOrange,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Description',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _promo!["description"] ?? "",
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Applies to estates',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.builder(
                                itemCount: (_promo!["estates"] as List?)?.length ?? 0,
                                itemBuilder: (ctx, i) {
                                  final e = _promo!["estates"][i] as Map;
                                  return FadeTransition(
                                    opacity: Tween<double>(begin: 0, end: 1).animate(
                                      CurvedAnimation(
                                        parent: _animationController,
                                        curve: Interval(0.1 * i, 1.0, curve: Curves.easeIn),
                                      ),
                                    ),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(-0.5, 0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _animationController,
                                          curve: Interval(0.1 * i, 1.0, curve: Curves.easeOut),
                                        ),
                                      ),
                                      child: Card(
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.all(16),
                                          leading: Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.apartment,
                                              color: Colors.green,
                                            ),
                                          ),
                                          title: Text(e["name"] ?? ""),
                                          subtitle: Text(e["location"] ?? ""),
                                          trailing: TextButton(
                                            child: const Text('View plots & prices'),
                                            onPressed: () => _openEstateModal(e["id"]),
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
                      ),
                    ),
                  ),
      ),
    );
  }

  void _openEstateModal(int estateId) async {
    final json = await _api.getEstateModalJson(estateId, token: widget.token);
    // show modal with sizes
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                json['estate_name'] ?? 'Estate',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.maxFinite,
                child: json['sizes'] == null
                    ? const Text('No sizes')
                    : ListView(
                        shrinkWrap: true,
                        children: List.from(json['sizes']).map<Widget>((s) {
                          return ListTile(
                            title: Text(s['size'] ?? ''),
                            trailing: Text(
                              s['amount'] != null
                                  ? NumberFormat.simpleCurrency(locale: 'en_NG', name: 'NGN')
                                      .format(s['amount'])
                                  : 'NO AMOUNT',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Truncate helper in extension
extension _StringExt on String {
  String truncate(int n) => length > n ? '${substring(0, n - 1)}…' : this;
}