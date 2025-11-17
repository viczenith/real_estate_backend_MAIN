import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:real_estate_app/shared/app_side.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:real_estate_app/shared/app_layout.dart';
import 'package:real_estate_app/client/client_bottom_nav.dart';

class ClientEstatePlotDetailsPage extends StatefulWidget {
  final int estateId;
  final int? plotSizeId;
  final String token;
  final String? title;

  const ClientEstatePlotDetailsPage({
    Key? key,
    required this.estateId,
    required this.token,
    this.plotSizeId,
    this.title,
  }) : super(key: key);

  @override
  State<ClientEstatePlotDetailsPage> createState() => _ClientEstatePlotDetailsPageState();
}

class _ClientEstatePlotDetailsPageState extends State<ClientEstatePlotDetailsPage> with TickerProviderStateMixin {
  final ApiService api = ApiService();
  late Future<Map<String, dynamic>> _future;
  final PageController _heroPageController = PageController(viewportFraction: 1.0);
  int _heroIndex = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final data = await api.fetchClientEstatePlotDetail(
      estateId: widget.estateId,
      plotSizeId: widget.plotSizeId,
      token: widget.token,
    );
    return data;
  }

  @override
  void dispose() {
    _heroPageController.dispose();
    super.dispose();
  }

  List<String> _collectHeroImages(Map<String, dynamic> estate, Map<String, dynamic>? plotSize) {
    final imgs = <String>[];
    // prototypes
    final protos = (estate['prototypes'] is List) ? estate['prototypes'] as List : [];
    for (final p in protos) {
      try {
        final m = p as Map;
        final ps = m['plot_size'];
        final matchesPlot = plotSize == null || (ps != null && (ps['id']?.toString() == plotSize['id']?.toString()));
        final url = (m['prototype_image'] ?? m['prototype_image_url'] ?? '').toString();
        if (matchesPlot && url.isNotEmpty) imgs.add(url);
      } catch (_) {}
    }

    // estate layouts
    final layouts = (estate['estate_layout'] is List) ? estate['estate_layout'] as List : [];
    for (final l in layouts) {
      try {
        final m = l as Map;
        final url = (m['layout_image'] ?? '').toString();
        if (url.isNotEmpty) imgs.add(url);
      } catch (_) {}
    }

    // floor plans
    final fps = (estate['floor_plans'] is List) ? estate['floor_plans'] as List : [];
    for (final f in fps) {
      try {
        final m = f as Map;
        final url = (m['floor_plan_image'] ?? '').toString();
        if (url.isNotEmpty) imgs.add(url);
      } catch (_) {}
    }

    // Ensure unique & keep order
    final unique = <String>[];
    for (final u in imgs) {
      if (!unique.contains(u)) unique.add(u);
    }
    return unique;
  }

  Widget _loading() => const Center(child: CircularProgressIndicator());

  Widget _error(Object e, StackTrace? st) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text('Failed to load estate', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(e.toString(), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ]),
      ),
    );
  }

  Future<void> _openMap(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Map not available')));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open map link')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openGallery(int initialIndex, List<String> images) {
    Navigator.of(context).push(PageRouteBuilder(pageBuilder: (ctx, a1, a2) {
      return _FullScreenGallery(images: images, initialIndex: initialIndex);
    }, transitionsBuilder: (ctx, anim, sec, child) {
      return FadeTransition(opacity: anim, child: child);
    }));
  }

  Widget _buildHeaderCarousel(List<String> images, String title, String subtitle) {
    if (images.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          color: Colors.blueGrey.shade50,
          height: 220,
          child: Center(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.blue.shade700, child: Text(title.isNotEmpty ? title[0] : 'E')),
              title: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              subtitle: Text(subtitle),
            ),
          ),
        ),
      );
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: 300,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(8)),
          child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        background: Stack(children: [
          PageView.builder(
            controller: _heroPageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _heroIndex = i),
            itemBuilder: (ctx, i) {
              final url = images[i];
              return GestureDetector(
                onTap: () => _openGallery(i, images),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (c, s) => Container(color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (c, s, e) => Container(color: Colors.grey.shade200, child: const Center(child: Icon(Icons.broken_image))),
                ),
              );
            },
          ),
          // position indicator
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
              child: Text('${_heroIndex + 1}/${images.length}', style: const TextStyle(color: Colors.white)),
            ),
          ),
          // gradient top
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black26, Colors.transparent]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // small helper to safely produce string
  String _safeStr(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppLayout(
      pageTitle: widget.title ?? 'Estate Details',
      token: widget.token,
      side: AppSide.client,
      child: Scaffold(
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) return _loading();
            if (snap.hasError) return _error(snap.error ?? 'Unknown error', snap.stackTrace);
            final estate = snap.data ?? <String, dynamic>{};

            // extract top-level info
            final estateName = _safeStr(estate['name'] ?? estate['estate_name'] ?? widget.title ?? 'Estate');
            final estateLocation = _safeStr(estate['location'] ?? estate['estate_location'] ?? '');
            final estateSize = _safeStr(estate['estate_size'] ?? estate['size'] ?? '');
            final titleDeed = _safeStr(estate['title_deed'] ?? estate['title'] ?? '');
            final plotSizeList = (estate['plot_size_units'] is List) ? estate['plot_size_units'] as List : [];
            Map<String, dynamic>? chosenPlotSize;
            if (widget.plotSizeId != null) {
              try {
                chosenPlotSize = plotSizeList.cast<Map>().firstWhere((m) => m['plot_size']?['id']?.toString() == widget.plotSizeId.toString()) as Map<String, dynamic>?;
              } catch (_) { chosenPlotSize = null; }
            } else {
              // try to guess first
              if (plotSizeList.isNotEmpty) {
                final first = plotSizeList.first;
                if (first is Map) chosenPlotSize = Map<String, dynamic>.from(first);
              }
            }

            String chosenPlotSizeLabel = '';
            try {
              if (chosenPlotSize != null && chosenPlotSize['plot_size'] is Map) {
                final ps = chosenPlotSize['plot_size'] as Map;
                chosenPlotSizeLabel = (ps['size']?.toString() ?? '');
              }
            } catch (_) {
              chosenPlotSizeLabel = '';
            }

            final heroImages = _collectHeroImages(estate, chosenPlotSize);
            final progress = (estate['progress_status'] is List) ? estate['progress_status'] as List : [];
            final amenities = (estate['estate_amenity'] is List) ? estate['estate_amenity'] as List : [];
            final prototypes = (estate['prototypes'] is List) ? estate['prototypes'] as List : [];
            final floorPlans = (estate['floor_plans'] is List) ? estate['floor_plans'] as List : [];
            final layouts = (estate['estate_layout'] is List) ? estate['estate_layout'] as List : [];
            final mapList = (estate['map'] is List) ? estate['map'] as List : [];
            final mapObj = mapList.isNotEmpty ? mapList.first as Map<String, dynamic> : null;
            final mapLink = _safeStr(mapObj?['generate_google_map_link'] ?? mapObj?['google_map_link']);

            // Build UI using slivers for nice collapse effect
            return CustomScrollView(
              slivers: [
                _buildHeaderCarousel(heroImages, estateName, estateLocation),
                
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        // switch columns by available width (responsive)
                        final int columns = width < 600 ? 1 : (width < 900 ? 2 : 3);
                        const double spacing = 12;
                        final double totalSpacing = (columns - 1) * spacing;
                        final double itemWidth = (width - totalSpacing) / columns;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: _InfoTile(title: 'Location', value: estateLocation, icon: Icons.location_on),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _InfoTile(title: 'Estate Size', value: estateSize, icon: Icons.landscape),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _InfoTile(title: 'Title Deed', value: titleDeed, icon: Icons.file_copy),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),


                // Progress Status
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: AnimationLimiter(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 600),
                        childAnimationBuilder: (widget) => SlideAnimation(horizontalOffset: 50.0, child: FadeInAnimation(child: widget)),
                        children: [
                          const SizedBox(height: 6),
                          Text('Progress Status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (progress.isEmpty)
                            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No progress updates available.', style: TextStyle(color: Colors.grey)))
                          else
                            ...progress.map((p) {
                              final pm = p is Map ? p : {};
                              final str = _safeStr(pm['progress_status'] ?? pm['status'] ?? '');
                              final tsRaw = pm['timestamp'] ?? pm['date'] ?? pm['timestamp'];
                              String when;
                              try {
                                when = tsRaw != null ? DateFormat('d MMM, yyyy').format(DateTime.parse(tsRaw.toString())) : '';
                              } catch (_) {
                                when = _safeStr(tsRaw);
                              }
                              return _ProgressRow(title: str, timestamp: when);
                            }).toList(),
                          const SizedBox(height: 12),
                        ],
                      )),
                    ),
                  ),
                ),

                // Amenities
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimationConfiguration.staggeredList(
                      position: 0,
                      duration: const Duration(milliseconds: 500),
                      child: SlideAnimation(child: FadeInAnimation(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Estate Amenities', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          if (amenities.isEmpty)
                            const Text('No amenities available for this estate.', style: TextStyle(color: Colors.grey))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: amenities.map<Widget>((a) {
                                try {
                                  final m = a as Map;
                                  // expecting amenities_display from serializer as list of [name, icon] pairs
                                  final display = m['amenities_display'] is List ? m['amenities_display'] as List : [];
                                  if (display.isEmpty) {
                                    // fallback to raw ids
                                    final raw = m['amenities']?.toString() ?? '';
                                    return Chip(label: Text(raw));
                                  }
                                  return Wrap(
                                    children: display.map<Widget>((dd) {
                                      String name = '';
                                      String icon = '';
                                      if (dd is List && dd.length >= 1) {
                                        name = dd[0]?.toString() ?? '';
                                        icon = dd.length > 1 ? (dd[1]?.toString() ?? '') : '';
                                      } else if (dd is Map) {
                                        name = dd['name']?.toString() ?? dd['display_name']?.toString() ?? '';
                                        icon = dd['icon']?.toString() ?? dd['icon_class']?.toString() ?? '';
                                      } else { name = dd?.toString() ?? ''; }
                                      // we can't map bootstrap icon classes to Flutter icons reliably; show simple chip
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6, bottom: 6),
                                        child: Chip(
                                          avatar: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                                          label: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                          backgroundColor: Colors.grey.shade50,
                                        ),
                                      );
                                    }).toList(),
                                  );
                                } catch (_) {
                                  return const SizedBox.shrink();
                                }
                              }).toList(),
                            ),
                          const SizedBox(height: 16),
                        ]),
                      )),
                    ),
                  ),
                ),

                // Prototypes (carousel)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${chosenPlotSizeLabel.isNotEmpty ? '$chosenPlotSizeLabel ' : ''}Prototypes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (prototypes.isEmpty)
                        const Text('No prototypes available for this plot size.', style: TextStyle(color: Colors.grey))
                      else
                        SizedBox(
                          height: 220,
                          child: PageView.builder(
                            controller: PageController(viewportFraction: 0.86),
                            itemCount: prototypes.length,
                            itemBuilder: (ctx, i) {
                              final p = prototypes[i] ?? {};
                              final m = p is Map ? p : {};
                              final image = _safeStr(m['prototype_image'] ?? m['prototype_image_url'] ?? '');
                              final title = _safeStr(m['Title'] ?? m['title'] ?? '');
                              final desc = _safeStr(m['Description'] ?? m['description'] ?? '');
                              return GestureDetector(
                                onTap: () {
                                  if (image.isNotEmpty) _openGallery(0, [image]);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0,6))],
                                  ),
                                  child: Column(children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: image.isNotEmpty
                                            ? CachedNetworkImage(imageUrl: image, width: double.infinity, fit: BoxFit.cover, placeholder: (c,s)=>Container(color: Colors.grey.shade100), errorWidget: (c,s,e)=>Container(color: Colors.grey.shade100,child:const Icon(Icons.broken_image)))
                                            : Container(color: Colors.grey.shade100, child: const Center(child: Icon(Icons.image_not_supported))),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Text(desc, style: const TextStyle(color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),

                                      ]),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                    ]),
                  ),
                ),

                // Layouts (grid)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Estate Layout', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (layouts.isEmpty)
                        const Text('No estate layouts available.', style: TextStyle(color: Colors.grey))
                      else
                        GridView.builder(
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: layouts.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, childAspectRatio: 2.0, mainAxisSpacing: 8),
                          itemBuilder: (ctx, i) {
                            final l = layouts[i] ?? {};
                            final m = l is Map ? Map<String, dynamic>.from(l) : (l as Map<String, dynamic>);
                            final image = _safeStr(m['layout_image'] ?? '');
                            return GestureDetector(
                              onTap: () => image.isNotEmpty ? _openGallery(0, [image]) : null,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: image.isNotEmpty
                                    ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, width: double.infinity, placeholder: (c,s)=>Container(color: Colors.grey.shade100), errorWidget: (c,s,e)=>Container(color: Colors.grey.shade100,child:const Icon(Icons.broken_image)))
                                    : Container(height: 140, color: Colors.grey.shade100, child: const Center(child: Icon(Icons.map))),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 12),
                    ]),
                  ),
                ),

                // Floor plans (list)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${chosenPlotSizeLabel.isNotEmpty ? '$chosenPlotSizeLabel ' : ''}Building Plans', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      if (floorPlans.isEmpty)
                        const Text('No floor plans available for this plot size.', style: TextStyle(color: Colors.grey))
                      else
                        Column(
                          children: floorPlans.map<Widget>((f) {
                            final m = f is Map ? f : {};
                            final image = _safeStr(m['floor_plan_image'] ?? '');
                            final title = _safeStr(m['plan_title'] ?? m['title'] ?? '');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GestureDetector(
                                onTap: () => image.isNotEmpty ? _openGallery(0, [image]) : null,
                                child: Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                      child: image.isNotEmpty
                                          ? CachedNetworkImage(imageUrl: image, width: 120, height: 90, fit: BoxFit.cover, placeholder: (c,s)=>Container(color: Colors.grey.shade100), errorWidget: (c,s,e)=>Container(color: Colors.grey.shade100,child:const Icon(Icons.broken_image)))
                                          : Container(width: 120, height: 90, color: Colors.grey.shade100, child: const Icon(Icons.photo_size_select_large)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                    ])),
                                    const SizedBox(width: 12),
                                    IconButton(icon: const Icon(Icons.open_in_full), onPressed: () => image.isNotEmpty ? _openGallery(0, [image]) : null),
                                  ]),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                    ]),
                  ),
                ),

                // // Map card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final theme = Theme.of(context);
                      final isNarrow = constraints.maxWidth < 520;

                      return Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openMap(mapLink),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: isNarrow
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // map preview (decorative)
                                      Container(
                                        height: 140,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [Colors.blue.shade600.withOpacity(0.12), Colors.blue.shade100.withOpacity(0.06)],
                                          ),
                                          border: Border.all(color: Colors.grey.shade100),
                                        ),
                                        child: Stack(
                                          children: [
                                            // decorative centered icon & text
                                            Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 56,
                                                    height: 56,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400]),
                                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0,4))],
                                                    ),
                                                    child: const Icon(Icons.place, color: Colors.white, size: 28),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Open in Maps',
                                                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.black54),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // address + actions
                                      Text('Locate Your Estate With Ease...', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 6),
                                      Text(
                                        estateLocation.isNotEmpty ? estateLocation : 'Open location in Google Maps',
                                        style: const TextStyle(color: Colors.black54),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () => _openMap(mapLink),
                                              icon: const Icon(Icons.launch),
                                              label: const Text('Open'),
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // subtle secondary action (same handler but visually lighter)
                                          SizedBox(
                                            width: 44,
                                            height: 44,
                                            child: OutlinedButton(
                                              onPressed: () => _openMap(mapLink),
                                              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                              child: const Icon(Icons.directions, size: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      // left: decorative preview
                                      Container(
                                        width: 140,
                                        height: 110,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [Colors.blue.shade600.withOpacity(0.12), Colors.blue.shade100.withOpacity(0.06)],
                                          ),
                                          border: Border.all(color: Colors.grey.shade100),
                                        ),
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: Align(
                                                alignment: Alignment.center,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 48,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400]),
                                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0,4))],
                                                      ),
                                                      child: const Icon(Icons.map_outlined, color: Colors.white, size: 26),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 14),
                                      // middle: text
                                      Expanded(
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('Estate Location', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 6),
                                          Text(
                                            estateLocation.isNotEmpty ? estateLocation : 'Open location in Google Maps',
                                            style: const TextStyle(color: Colors.black54),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ]),
                                      ),

                                      const SizedBox(width: 12),
                                      // right: actions
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(minWidth: 90),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () => _openMap(mapLink),
                                              icon: const Icon(Icons.launch),
                                              label: const Text('Open'),
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: OutlinedButton(
                                                onPressed: () => _openMap(mapLink),
                                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                                child: const Icon(Icons.directions, size: 20),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // bottom spacing and back button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 16),
                    child: Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Properties'),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
        // Attach the ClientBottomNav so users can navigate back to other client screens.
        bottomNavigationBar: ClientBottomNav(
          currentIndex: 1, // best-effort: details/details page index
          token: widget.token,
          chatBadge: 0,
        ),
      ),
    );
  }

}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _InfoTile({Key? key, required this.title, required this.value, required this.icon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.blueAccent)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String title;
  final String timestamp;
  const _ProgressRow({Key? key, required this.title, required this.timestamp}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(timestamp, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenGallery({Key? key, required this.images, this.initialIndex = 0}) : super(key: key);
  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController controller;
  late int index;
  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    controller = PageController(initialPage: index);
  }
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text('${index+1}/${widget.images.length}')),
      body: PhotoViewGallery.builder(
        pageController: controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => index = i),
        builder: (ctx, i) {
          final url = widget.images[i];
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(url),
            minScale: PhotoViewComputedScale.contained * 0.9,
            maxScale: PhotoViewComputedScale.covered * 3.0,
            heroAttributes: PhotoViewHeroAttributes(tag: url),
          );
        },
        loadingBuilder: (c, event) => const Center(child: CircularProgressIndicator()),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}
