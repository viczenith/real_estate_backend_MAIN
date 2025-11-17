import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:real_estate_app/admin_support/admin_support_bottom_nav.dart';
import 'package:real_estate_app/admin_support/admin_support_layout.dart';
import 'package:real_estate_app/core/api_service.dart';

class AdminSupportSpecialDaysPage extends StatefulWidget {
  final String token;

  const AdminSupportSpecialDaysPage({super.key, required this.token});

  @override
  State<AdminSupportSpecialDaysPage> createState() => _AdminSupportSpecialDaysPageState();
}

class _AdminSupportSpecialDaysPageState extends State<AdminSupportSpecialDaysPage> {
  final ApiService _api = ApiService();

  bool _loading = true;
  String? _error;
  List<SpecialDayEntry> _today = const [];
  List<SpecialDayEntry> _thisWeek = const [];
  List<SpecialDayEntry> _thisMonth = const [];
  DateTime? _generatedAt;
  DateTimeRange? _weekRange;
  int? _summaryMonth;
  int? _summaryYear;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final payload = await _api.fetchSupportSpecialDaySummary(widget.token);
      if (!mounted) return;

      List<SpecialDayEntry> parseEntries(dynamic raw) {
        if (raw is List) {
          return raw
              .map((item) => SpecialDayEntry.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return <SpecialDayEntry>[];
      }

      DateTimeRange? parseRange(Map<String, dynamic>? json) {
        if (json == null) return null;
        final startStr = json['start'] as String?;
        final endStr = json['end'] as String?;
        if (startStr == null || endStr == null) return null;
        try {
          return DateTimeRange(
            start: DateTime.parse(startStr),
            end: DateTime.parse(endStr),
          );
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
        _summaryMonth = payload['month'] is int ? payload['month'] as int : int.tryParse('${payload['month']}');
        _summaryYear = payload['year'] is int ? payload['year'] as int : int.tryParse('${payload['year']}');
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load special days right now. Pull to retry.';
      });
    }
  }

  Future<void> _handleCreateCustomDay() async {
    final created = await _showCreateCustomDayDialog();
    if (created == true) {
      if (!mounted) return;
      await _loadSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom special day added to calendar')),
      );
    }
  }

  Future<bool?> _showCreateCustomDayDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? selectedDate = DateTime.now();
    String? errorText;
    bool saving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final initial = selectedDate ?? now;
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: initial,
                firstDate: DateTime(now.year - 5),
                lastDate: DateTime(now.year + 5),
              );
              if (picked != null) {
                setDialogState(() {
                  selectedDate = picked;
                });
              }
            }

            Future<void> submit() async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                setDialogState(() {
                  errorText = 'Please enter a name';
                });
                return;
              }

              if (selectedDate == null) {
                setDialogState(() {
                  errorText = 'Select a date for this special day';
                });
                return;
              }

              setDialogState(() {
                saving = true;
                errorText = null;
              });

              try {
                await _api.createCustomSpecialDay(
                  token: widget.token,
                  name: name,
                  date: selectedDate!,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                );
                if (!mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (err) {
                setDialogState(() {
                  saving = false;
                  errorText = _friendlyErrorMessage(err);
                });
              }
            }

            final dateLabel = selectedDate != null
                ? DateFormat('EEE, MMM d, yyyy').format(selectedDate!)
                : 'Pick event date';

            return AlertDialog(
              title: const Text('Add Custom Special Day'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g., Company Anniversary',
                      ),
                      textCapitalization: TextCapitalization.words,
                      enabled: !saving,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(dateLabel),
                      subtitle: const Text('Tap to choose the date'),
                      onTap: saving ? null : () => pickDate(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText: 'Add any context for your team…',
                      ),
                      minLines: 2,
                      maxLines: 4,
                      enabled: !saving,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : submit,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    return result;
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString();
    final cleaned = raw.startsWith('Exception:') ? raw.substring('Exception:'.length).trim() : raw.trim();
    if (cleaned.isEmpty) {
      return 'Something went wrong. Please try again.';
    }
    return cleaned;
  }

  bool get _hasData => _today.isNotEmpty || _thisWeek.isNotEmpty || _thisMonth.isNotEmpty;

  String? get _monthLabel {
    final month = _summaryMonth;
    final year = _summaryYear;
    if (month == null || year == null) return null;
    try {
      final dt = DateTime(year, month);
      return DateFormat('MMMM yyyy').format(dt);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminSupportLayout(
      token: widget.token,
      pageTitle: 'Admin Support • Nigeria Days',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: AdminSupportBottomNav(currentIndex: 3, token: widget.token),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: RefreshIndicator(
            onRefresh: () => _loadSummary(showSpinner: false),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 720;
                final slivers = _buildSlivers(context, isNarrow);

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

  List<Widget> _buildSlivers(BuildContext context, bool isNarrow) {
    final theme = Theme.of(context);
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nigeria Special Days',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Spotlight national and cultural moments to plan high-impact outreach for clients and marketers.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_weekRange != null)
                  _InfoChip(
                    icon: Icons.calendar_month_rounded,
                    label: _formatRange(_weekRange!),
                  ),
                if (_generatedAt != null)
                  _InfoChip(
                    icon: Icons.update_rounded,
                    label: 'Updated ${DateFormat.jm().format(_generatedAt!.toLocal())}',
                  ),
                if (_monthLabel != null)
                  _InfoChip(
                    icon: Icons.event_note_outlined,
                    label: _monthLabel!,
                  ),
                  
                FilledButton.icon(
                  onPressed: _loading ? null : _handleCreateCustomDay,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Custom Special Day'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ];

    if (_loading && !_hasData) {
      slivers.add(const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ));
      return slivers;
    }

    if (_error != null && !_hasData) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: _ErrorState(message: _error!, onRetry: () => _loadSummary()),
      ));
      return slivers;
    }

    if (_error != null) {
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _InlineErrorBanner(message: _error!, onRetry: () => _loadSummary()),
        ),
      ));
    }

    slivers.add(_buildTodaySection(context));
    slivers.add(_buildWeekSection(context, isNarrow));
    slivers.add(_buildMonthSection(context));
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 32)));
    return slivers;
  }

  Widget _buildTodaySection(BuildContext context) {
    final theme = Theme.of(context);
    if (_today.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: _EmptyState(
            icon: Icons.flag_outlined,
            title: 'No special observances today',
            subtitle: 'Keep an eye on this space to catch cultural moments as soon as they start.',
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Today’s Highlights',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _today.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) => _TodayHighlightCard(entry: _today[index]),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildWeekSection(BuildContext context, bool isNarrow) {
    final theme = Theme.of(context);
    final buckets = _weekBuckets();

    if (buckets.isEmpty) {
      return const SliverToBoxAdapter(
        child: _EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'No upcoming cultural days',
          subtitle: 'We’ll surface national and custom Nigerian events for the week once they are announced.',
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'This Week',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...buckets.map((bucket) => _WeekDayCard(bucket: bucket, compact: isNarrow)),
        ],
      ),
    );
  }

  List<_WeekBucket> _weekBuckets() {
    final todayKeys = _today.map((e) => e.date).where((d) => d.isNotEmpty).toSet();
    final map = <String, List<SpecialDayEntry>>{};

    for (final entry in _thisWeek) {
      if (entry.date.isEmpty) continue;
      if (todayKeys.contains(entry.date)) continue;
      map.putIfAbsent(entry.date, () => []).add(entry);
    }

    final buckets = map.entries.map((e) {
      final dateTime = DateTime.tryParse(e.key);
      e.value.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return _WeekBucket(dateKey: e.key, date: dateTime, entries: e.value);
    }).toList();

    buckets.sort((a, b) {
      if (a.date == null && b.date == null) return a.dateKey.compareTo(b.dateKey);
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });
    return buckets;
  }

  Widget _buildMonthSection(BuildContext context) {
    if (_thisMonth.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final entries = _thisMonth.toList()
      ..sort((a, b) {
        final aDate = a.dateTime;
        final bDate = b.dateTime;
        if (aDate == null && bDate == null) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        final cmp = aDate.compareTo(bDate);
        if (cmp != 0) return cmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    String formatDate(SpecialDayEntry entry) {
      final dt = entry.dateTime;
      if (dt == null) return 'Date TBC';
      return DateFormat('EEE, MMM d').format(dt.toLocal());
    }

    Color statusColor(SpecialDayEntry entry) {
      if (entry.isAdminCreated) {
        return theme.colorScheme.secondary;
      }
      if (entry.isNigerian) {
        return theme.colorScheme.primary;
      }
      return theme.colorScheme.tertiary;
    }

    String statusLabel(SpecialDayEntry entry) {
      if (entry.isAdminCreated) return 'Custom';
      if (entry.isNigerian) return 'National';
      return entry.categoryLabel;
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'All Special Days This Month',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(entry),
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor(entry).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel(entry),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: statusColor(entry),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (entry.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      entry.description.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (entry.isNigerian)
                        const _InfoChip(
                          icon: Icons.flag,
                          label: 'Nigeria',
                        ),
                      if (entry.isAdminCreated)
                        const _InfoChip(
                          icon: Icons.person_outline,
                          label: 'Admin Created',
                        ),
                      if (!entry.isAdminCreated && entry.source.isNotEmpty)
                        _InfoChip(
                          icon: Icons.public_outlined,
                          label: entry.source,
                        ),
                      if (entry.isRecurring)
                        const _InfoChip(
                          icon: Icons.repeat_rounded,
                          label: 'Recurring',
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatRange(DateTimeRange range) {
    final formatter = DateFormat('EEE, MMM d');
    final start = formatter.format(range.start.toLocal());
    final end = formatter.format(range.end.toLocal());
    return 'Week: $start – $end';
  }
}

class SpecialDayEntry {
  final String id;
  final String name;
  final String title;
  final String date;
  final String description;
  final String type;
  final String category;
  final String source;
  final String countryCode;
  final bool isNigerian;
  final bool isCustom;
  final bool isRecurring;
  final String localEventId;
  final bool isAdminCreated;

  const SpecialDayEntry({
    required this.id,
    required this.name,
    required this.title,
    required this.date,
    required this.description,
    required this.type,
    required this.category,
    required this.source,
    required this.countryCode,
    required this.isNigerian,
    required this.isCustom,
    required this.isRecurring,
    required this.localEventId,
    required this.isAdminCreated,
  });

  factory SpecialDayEntry.fromJson(Map<String, dynamic> json) {
    String resolveId(dynamic raw) {
      if (raw == null) return UniqueKey().toString();
      return raw.toString();
    }

    final rawCategory = (json['category'] ?? json['type'] ?? 'custom').toString();
    final rawType = (json['type'] ?? rawCategory).toString();
    final rawSource = (json['source'] ?? '').toString();
    final localEventId = (json['localEventId'] ?? '').toString();
    final isCustom = json['isCustom'] == true || rawCategory.toLowerCase() == 'custom';
    final isRecurring = json['isRecurring'] == true;
    final isAdminCreated = rawSource.toLowerCase() == 'local' || localEventId.isNotEmpty;

    return SpecialDayEntry(
      id: resolveId(json['id']),
      name: (json['name'] ?? json['title'] ?? 'Event') as String,
      title: (json['title'] ?? json['name'] ?? 'Event') as String,
      date: (json['date'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      type: rawType,
      category: rawCategory,
      source: rawSource,
      countryCode: (json['countryCode'] ?? '') as String,
      isNigerian: json['isNigerian'] == true,
      isCustom: isCustom,
      isRecurring: isRecurring,
      localEventId: localEventId,
      isAdminCreated: isAdminCreated,
    );
  }

  DateTime? get dateTime {
    if (date.isEmpty) return null;
    return DateTime.tryParse(date);
  }

  String get formattedDate {
    final dt = dateTime;
    if (dt == null) return 'Date TBC';
    return DateFormat('EEE, MMM d').format(dt.toLocal());
  }

  String get categoryLabel {
    if (isNigerian) return 'National';
    if (category.isNotEmpty) return category[0].toUpperCase() + category.substring(1);
    if (type.isNotEmpty) return type[0].toUpperCase() + type.substring(1);
    return 'Special';
  }

  bool get isLocalCustom => isAdminCreated;

  bool get isUpcoming {
    final dt = dateTime;
    if (dt == null) return false;
    final today = DateTime.now();
    return !dt.isBefore(DateTime(today.year, today.month, today.day));
  }
}

class _WeekBucket {
  final String dateKey;
  final DateTime? date;
  final List<SpecialDayEntry> entries;

  const _WeekBucket({required this.dateKey, required this.date, required this.entries});

  String get formattedHeading {
    if (date != null) {
      final formatter = DateFormat('EEEE • MMM d');
      return formatter.format(date!.toLocal());
    }
    return dateKey;
  }
}

Color _resolveAccentColor(SpecialDayEntry entry, ThemeData theme) {
  if (entry.isAdminCreated) {
    return const Color(0xFFFF8A00);
  }
  if (entry.isNigerian) {
    return const Color(0xFF0B8043);
  }
  switch (entry.category.toLowerCase()) {
    case 'religious':
      return const Color(0xFF512DA8);
    case 'commercial':
      return const Color(0xFF1565C0);
    case 'observance':
      return const Color(0xFF6A1B9A);
    default:
      return theme.colorScheme.primary;
  }
}

class _TodayHighlightCard extends StatelessWidget {
  final SpecialDayEntry entry;

  const _TodayHighlightCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _resolveAccentColor(entry, theme);

    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withOpacity(0.12), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: accent.withOpacity(0.12),
                child: Text(entry.categoryLabel[0], style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(entry.formattedDate, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              entry.description.isNotEmpty ? entry.description : 'Use this moment to celebrate with your audience.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _Pill(label: entry.categoryLabel, color: accent),
              if (entry.isAdminCreated)
                _Pill(label: 'Admin Calendar', color: Colors.deepOrange),
              if (entry.isRecurring)
                _Pill(label: 'Recurring', color: Colors.teal),
              if (entry.source.isNotEmpty && !entry.isAdminCreated)
                _Pill(label: entry.source.toUpperCase(), color: Colors.deepOrange),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  final _WeekBucket bucket;
  final bool compact;

  const _WeekDayCard({required this.bucket, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: theme.colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bucket.formattedHeading,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${bucket.entries.length} event${bucket.entries.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 14),
          ...bucket.entries.map((entry) => _WeekDayEventTile(entry: entry, compact: compact)),
        ],
      ),
    );
  }
}

class _WeekDayEventTile extends StatelessWidget {
  final SpecialDayEntry entry;
  final bool compact;

  const _WeekDayEventTile({required this.entry, this.compact = false});

  IconData _iconForEntry() {
    if (entry.isAdminCreated) return Icons.workspace_premium_outlined;
    if (entry.isNigerian) return Icons.flag_circle_outlined;
    switch (entry.category.toLowerCase()) {
      case 'religious':
        return Icons.church_outlined;
      case 'observance':
        return Icons.auto_awesome;
      case 'commercial':
        return Icons.storefront_outlined;
      default:
        return Icons.event_note_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _resolveAccentColor(entry, theme);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconForEntry(), color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.description.isNotEmpty
                      ? entry.description
                      : 'Plan celebratory messages or exclusive offers to match this cultural moment.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black87, height: 1.45),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Pill(label: entry.categoryLabel, color: accent),
                    if (entry.isAdminCreated)
                      _Pill(label: 'Admin Calendar', color: Colors.deepOrange),
                    if (entry.isRecurring)
                      _Pill(label: 'Recurring', color: Colors.teal),
                    if (entry.countryCode.isNotEmpty && !entry.isNigerian)
                      _Pill(label: entry.countryCode.toUpperCase(), color: Colors.indigo),
                    if (!entry.isNigerian && !entry.isAdminCreated && entry.isUpcoming)
                      const _Pill(label: 'Global', color: Colors.deepOrange),
                  ],
                ),
              ],
            ),
          ),
          if (!compact)
            IconButton(
              tooltip: 'Plan outreach',
              onPressed: () {},
              icon: const Icon(Icons.arrow_outward_rounded),
            ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey.shade700),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.darken(0.2),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

extension on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
