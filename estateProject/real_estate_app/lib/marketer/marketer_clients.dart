import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:real_estate_app/shared/app_side.dart';
import 'package:real_estate_app/shared/app_layout.dart';
import 'package:real_estate_app/marketer/marketer_bottom_nav.dart';
import 'package:real_estate_app/core/api_service.dart';

class MarketerClients extends StatefulWidget {
  final String token;
  final int? marketerId;

  const MarketerClients({required this.token, this.marketerId, Key? key}) : super(key: key);

  @override
  _MarketerClientsState createState() => _MarketerClientsState();
}

class _MarketerClientsState extends State<MarketerClients> with TickerProviderStateMixin {
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> _clients = [];
  int _page = 1;
  int _pageSize = 12;
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  final FocusNode _searchFocusNode = FocusNode();

  late final AnimationController _revealController;
  late final Animation<double> _revealAnimation;

  late final AnimationController _pulseController;

  final Map<int, Map<String, dynamic>?> _clientDetailCache = {};
  final Set<int> _expanded = {};

  final NumberFormat _currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  final DateFormat _dateFmt = DateFormat('MMM d, y');

  late final AnimationController _searchAnimationController;
  late final Animation<double> _searchAnimation;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _revealAnimation = CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    // Search animation controller
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );

    _loadClients(reset: true);
  }

  @override
  void dispose() {
    _revealController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pulseController.dispose();
    _searchAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadClients({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _clients = [];
        _totalCount = 0;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final result = await _api.fetchMarketerClients(
        token: widget.token,
        marketerId: widget.marketerId,
        page: _page,
        pageSize: _pageSize,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );

      // result is paginated DRF map: {count, next, previous, results}
      final List<dynamic> results = result['results'] ?? [];
      final count = result['count'] ?? 0;

      setState(() {
        _totalCount = count as int;
        if (reset) {
          _clients = results.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else {
          _clients.addAll(results.map((e) => Map<String, dynamic>.from(e as Map)).toList());
        }
      });

      // reveal animation once data loaded
      _revealController.forward();
    } catch (e, st) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    if (_isLoadingMore) return;
    if (_clients.length >= _totalCount) return;
    _page += 1;
    await _loadClients(reset: false);
  }

  // Fetch full grouped transactions for client (modal/detail). Caches result.
  Future<Map<String, dynamic>?> _fetchClientDetail(int clientId) async {
    if (_clientDetailCache.containsKey(clientId)) return _clientDetailCache[clientId];
    try {
      final data = await _api.getMarketerClientDetail(clientId: clientId, token: widget.token, marketerId: widget.marketerId);
      _clientDetailCache[clientId] = data;
      return data;
    } catch (e) {
      rethrow;
    }
  }

  // Helper: safe nested read, returns '' if not found
  String _readNestedString(Map? m, List<String> path) {
    dynamic cur = m;
    for (final p in path) {
      if (cur is Map && cur.containsKey(p)) {
        cur = cur[p];
      } else {
        return '';
      }
    }
    return cur?.toString() ?? '';
  }


  Future<void> _openWhatsApp(String? rawPhone) async {
    if (rawPhone == null || rawPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client has no phone number.')));
      return;
    }

    String phone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.startsWith('+')) phone = phone.substring(1);

    if (phone.startsWith('0')) {
      phone = '234' + phone.substring(1);
    }

    final Uri appUri = Uri.parse('whatsapp://send?phone=$phone');
    final Uri webUri = Uri.parse('https://wa.me/$phone');

    try {
      if (await canLaunchUrl(appUri)) {
        final launched = await launchUrl(appUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }

      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }

      await launchUrl(webUri, mode: LaunchMode.platformDefault);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp link.')));
    }
  }

  Future<void> _showClientDetail(int clientId, String clientName) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.35,
          maxChildSize: 0.98,
          builder: (ctx, ctrl) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: _fetchClientDetail(clientId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary))),
                  );
                } else if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('Failed to load client details', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Text(snap.error.toString(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _clientDetailCache.remove(clientId);
                            });
                            Navigator.of(context).pop();
                            _showClientDetail(clientId, clientName);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        )
                      ],
                    ),
                  );
                }

                final data = snap.data;
                if (data == null) {
                  return const SizedBox.shrink();
                }

                final transactionsByEstate = (data['transactions_by_estate'] as List<dynamic>?) ?? [];

                return SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: CustomScrollView(
                      controller: ctrl,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(clientName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
                                  IconButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.grey.shade200,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Transactions grouped by estate', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, idx) {
                            final block = transactionsByEstate[idx] as Map<String, dynamic>;
                            final estate = block['estate'] as Map<String, dynamic>?;
                            final estateName = estate != null ? estate['name'] as String? ?? 'Estate' : 'Estate';
                            final txs = (block['transactions'] as List<dynamic>?) ?? [];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.apartment, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(estateName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text('${txs.length} tx', style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w600
                                          )),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ...txs.map<Widget>((t) {
                                      final txn = Map<String, dynamic>.from(t as Map);
                                      final amount = txn['total_amount']?.toString() ?? '0';
                                      final status = txn['status']?.toString() ?? '';
                                      final plotSize = _readNestedString(txn, ['plot_size']) // fallback
                                          .isNotEmpty ? _readNestedString(txn, ['plot_size']) : _readNestedString(txn, ['allocation','plot_size','size']);
                                      final plotNumber = _readNestedString(txn, ['plot_number']);
                                      final transDate = txn['transaction_date']?.toString() ?? '';

                                      final bool allocated = plotNumber.isNotEmpty;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(plotSize.isNotEmpty ? plotSize : '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                                  const SizedBox(height: 4),
                                                  Text('$transDate • ${txn['payment_type'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(_formatCurrencySafe(amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: allocated ? Colors.green.shade50 : Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        allocated ? Icons.check_circle : Icons.cancel,
                                                        size: 14,
                                                        color: allocated ? Colors.green.shade700 : Colors.red.shade700,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        allocated ? 'Allocated' : 'Not Allocated',
                                                        style: TextStyle(
                                                          color: allocated ? Colors.green.shade700 : Colors.red.shade700,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w600
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            );
                          }, childCount: transactionsByEstate.length),
                        ),
                        SliverToBoxAdapter(child: const SizedBox(height: 24)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatCurrencySafe(String raw) {
    try {
      final cleaned = raw.replaceAll(',', '');
      final numVal = double.tryParse(cleaned) ?? 0;
      return _currency.format(numVal);
    } catch (_) {
      return raw;
    }
  }

  Widget _buildClientCard(Map<String, dynamic> client, int index) {
    final id = (client['id'] is int) ? client['id'] as int : int.tryParse(client['id']?.toString() ?? '') ?? 0;
    final fullName = client['full_name'] as String? ?? 'No Name';
    final email = client['email'] as String? ?? '';
    final phone = client['phone_number'] as String? ?? client['phone'] as String? ?? '';
    final profileImage = client['profile_image'] as String?;
    final address = client['address'] as String? ?? 'Not provided';
    final dateJoinedRaw = client['date_registered'] as String?;
    final DateTime? dateJoined = dateJoinedRaw != null ? DateTime.tryParse(dateJoinedRaw) : null;
    final dynamic totalTxRaw = client['total_transactions'] ?? (client['transactions'] is List ? (client['transactions'] as List).length : 0);
    final String totalTx = totalTxRaw?.toString() ?? '0';
    final recentTx = (client['recent_transactions'] as List<dynamic>?) ?? [];

    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _revealController, curve: Interval(0.02 * (index % 6), 0.6, curve: Curves.easeOut))),
      child: Transform.translate(
        offset: Offset(0, 14 + (6 - (index % 6)).toDouble()),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showClientDetail(id, fullName),
            child: Column(
              children: [
                // header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: Colors.white24, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4)
                            )
                          ]
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: profileImage != null && profileImage.isNotEmpty
                              ? Image.network(
                                  profileImage.startsWith('http') ? profileImage : '${_api.baseUrl}${profileImage}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(),
                                )
                              : _buildPlaceholderAvatar(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                            const SizedBox(height: 6),
                            Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                      // Live badge
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.96, end: 1.04).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white30)
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.circle, size: 10, color: Colors.greenAccent),
                              SizedBox(width: 8),
                              Text('Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // body
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // summary row
                      Row(
                        children: [
                          Expanded(
                            child: _summaryTile(
                              icon: Icons.email,
                              label: 'Email',
                              value: email,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryTile(
                              icon: Icons.location_on,
                              label: 'Address',
                              value: address,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryTile(
                              icon: Icons.how_to_vote,
                              label: 'Total Estates',
                              value: totalTx,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (recentTx.isNotEmpty)
                        Column(
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Recent Transactions', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 12),
                            ...recentTx.map((rt) {
                              final Map<String, dynamic> tx = Map<String, dynamic>.from(rt as Map);
                              final plotSize = _readNestedString(tx, ['allocation','plot_size','size']).isNotEmpty
                                  ? _readNestedString(tx, ['allocation','plot_size','size'])
                                  : _readNestedString(tx, ['allocation','plot_size']);
                              final amount = tx['total_amount']?.toString() ?? '0';
                              final paymentStatus = tx['status']?.toString() ?? '';
                              final allocated = _readNestedString(tx, ['allocation','plot_number']).isNotEmpty;
                              final txnDate = tx['transaction_date']?.toString() ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(plotSize.isNotEmpty ? plotSize : '-', style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14
                                      )),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_formatCurrencySafe(amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Text(txnDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (paymentStatus.toLowerCase().contains('paid') ? Colors.green.shade50 : Colors.orange.shade50),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        paymentStatus,
                                        style: TextStyle(
                                          color: paymentStatus.toLowerCase().contains('paid') ? Colors.green.shade700 : Colors.orange.shade700,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 8),
                          ],
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('No transactions yet', style: TextStyle(color: Colors.grey.shade600)),
                        )
                    ],
                  ),
                ),

                // footer actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(phone),
                        icon: const Icon(FontAwesomeIcons.whatsapp, size: 18, color: Colors.white),
                        label: const Text(
                          'Send Message',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),

                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _showClientDetail(id, fullName),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text('View Details'),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          if (_expanded.contains(id)) {
                            setState(() => _expanded.remove(id));
                          } else {
                            setState(() => _expanded.add(id));
                            _fetchClientDetail(id).catchError((e) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load client details: $e')));
                            });
                          }
                        },
                        icon: Icon(_expanded.contains(id) ? Icons.expand_less : Icons.expand_more),
                        tooltip: 'Quick view',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                      )
                    ],
                  ),
                ),

                if (_expanded.contains(id))
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _fetchClientDetail(id),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary))),
                        );
                      } else if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Failed to load: ${snap.error}', style: const TextStyle(color: Colors.red)),
                        );
                      } else {
                        final data = snap.data;
                        if (data == null) return const SizedBox.shrink();
                        final groups = (data['transactions_by_estate'] as List<dynamic>?) ?? [];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: groups.map<Widget>((g) {
                              final Map block = g as Map;
                              final estate = (block['estate'] as Map?) ?? {'name': 'Unknown'};
                              final estateName = estate['name']?.toString() ?? 'Estate';
                              final txs = (block['transactions'] as List?) ?? [];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.apartment, color: Theme.of(context).colorScheme.primary, size: 20),
                                ),
                                title: Text(estateName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                subtitle: Text('${txs.length} transaction${txs.length == 1 ? '' : 's'}', style: const TextStyle(color: Colors.grey)),
                                trailing: IconButton(
                                  onPressed: () {
                                    _showClientDetail(id, fullName);
                                  },
                                  icon: const Icon(Icons.open_in_new, size: 20),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.grey.shade100,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderAvatar() {
    return Container(
      color: Colors.grey.shade300,
      child: Icon(Icons.person, color: Colors.grey.shade600, size: 32),
    );
  }

  Widget _summaryTile({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingSkeleton();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text('Failed to load clients', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Colors.red.shade600), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _loadClients(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_clients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 76, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Client Not Found', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoadingMore && scrollInfo.metrics.pixels >= (scrollInfo.metrics.maxScrollExtent - 120)) {
          // nearing bottom
          _loadMoreIfNeeded();
        }
        return false;
      },
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: _clients.length + 1,
        itemBuilder: (context, i) {
          if (i == _clients.length) {
            if (_clients.length < _totalCount) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary))),
              );
            } else {
              return const SizedBox(height: 48);
            }
          }
          final client = _clients[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildClientCard(client, i),
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      children: List.generate(4, (i) => _skeletonCard()).toList(),
    );
  }

  Widget _skeletonCard() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(40)
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 16, width: double.infinity, color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                  Container(height: 12, width: 140, color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: Container(height: 14, color: Colors.grey.shade200)),
                      const SizedBox(width: 12),
                      Expanded(child: Container(height: 14, color: Colors.grey.shade200)),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return AppLayout(
      pageTitle: 'Client Records',
      token: widget.token,
      side: AppSide.marketer,
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey.shade900.withOpacity(0.98) : Colors.grey.shade50,
        bottomNavigationBar: MarketerBottomNav(currentIndex: 1, token: widget.token, chatBadge: 0),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => _loadClients(reset: true),
            color: Theme.of(context).colorScheme.primary,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Client Records', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24
                                )),
                                const SizedBox(height: 6),
                                Text('Home / Client Records', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                              ],
                            ),
                          ),
                          if (screenWidth > 800)
                            SizedBox(
                              width: 340,
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: (v) {
                                  _searchDebounce?.cancel();
                                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                                    _loadClients(reset: true);
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search clients (name, email, phone)',
                                  prefixIcon: const Icon(Icons.search),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.all(14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.grey.shade400),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? Colors.grey.shade800 : Colors.white,
                                ),
                              ),
                            ),
                          if (screenWidth > 800) const SizedBox(width: 12),
                          if (screenWidth > 800)
                            ElevatedButton.icon(
                              onPressed: () => _loadClients(reset: true),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                        ],
                      ),

                      if (screenWidth <= 800) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                onChanged: (v) {
                                  _searchDebounce?.cancel();
                                  _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                                    _loadClients(reset: true);
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search clients (name, email, phone)',
                                  prefixIcon: const Icon(Icons.search),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.all(14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.grey.shade400),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? Colors.grey.shade800 : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => _loadClients(reset: true),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Body (list)
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _buildBody())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

