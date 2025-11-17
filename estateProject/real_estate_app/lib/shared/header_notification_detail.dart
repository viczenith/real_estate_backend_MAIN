import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

/// Beautiful notification detail screen opened from header dropdown.
/// Shows full HTML content with modern design and marks notification as read.
class HeaderNotificationDetail extends StatefulWidget {
  final String token;
  final int userNotificationId;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool initialReadStatus;

  const HeaderNotificationDetail({
    Key? key,
    required this.token,
    required this.userNotificationId,
    required this.title,
    required this.body,
    required this.timestamp,
    this.initialReadStatus = false,
  }) : super(key: key);

  @override
  State<HeaderNotificationDetail> createState() =>
      _HeaderNotificationDetailState();
}

class _HeaderNotificationDetailState extends State<HeaderNotificationDetail>
    with SingleTickerProviderStateMixin {
  bool _isRead = false;
  bool _isMarking = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isRead = widget.initialReadStatus;

    // Initialize animations
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    // Start animations
    _animController.forward();

    // Automatically mark as read when opened (if not already read)
    if (!_isRead) {
      _markAsRead();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    if (_isMarking) return;
    setState(() => _isMarking = true);

    try {
      await ApiService().markHeaderNotificationRead(
        token: widget.token,
        userNotificationId: widget.userNotificationId,
      );
      if (mounted) {
        setState(() => _isRead = true);
      }
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    } finally {
      if (mounted) {
        setState(() => _isMarking = false);
      }
    }
  }

  String _formatTimestamp(DateTime dt) {
    try {
      return DateFormat('MMM d, yyyy • h:mm a').format(dt.toLocal());
    } catch (e) {
      return dt.toLocal().toString();
    }
  }

  String _getRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dt);
    }
  }

  /// Decodes HTML entities including emoji codes
  String _decodeHtmlEntities(String text) {
    if (text.isEmpty) return text;

    String result = text;

    // Decode common HTML entities
    result = result
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'");

    // Decode numeric HTML entities (including emoji codes like &#128512;)
    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null) {
        try {
          // Use String.fromCharCodes to properly handle Unicode code points beyond BMP
          if (code <= 0xFFFF) {
            return String.fromCharCode(code);
          } else {
            // Handle surrogate pairs for code points > 0xFFFF
            return String.fromCharCodes([code]);
          }
        } catch (e) {
          return match.group(0) ?? '';
        }
      }
      return match.group(0) ?? '';
    });

    // Decode hex HTML entities (including emoji codes like &#x1F600;)
    result = result.replaceAllMapped(RegExp(r'&#[xX]([0-9A-Fa-f]+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      if (code != null) {
        try {
          // Use String.fromCharCodes to properly handle Unicode code points beyond BMP
          if (code <= 0xFFFF) {
            return String.fromCharCode(code);
          } else {
            // Handle surrogate pairs for code points > 0xFFFF
            return String.fromCharCodes([code]);
          }
        } catch (e) {
          return match.group(0) ?? '';
        }
      }
      return match.group(0) ?? '';
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: isDark ? Colors.white : Colors.grey.shade800,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        actions: [
          if (_isRead)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle,
                      size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Read',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Stack(
            children: [
              // Gradient Background Header
              Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF667eea),
                      const Color(0xFF764ba2),
                      Colors.deepPurple.shade600,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      left: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Main Content
              SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Hero Header Card
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon & Badge
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.deepPurple.shade400,
                                          Colors.purple.shade600,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.deepPurple
                                              .withOpacity(0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.notifications_active_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Notification',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              size: 14,
                                              color: Colors.deepPurple.shade400,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _getRelativeTime(
                                                  widget.timestamp),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color:
                                                    Colors.deepPurple.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Title (with emoji support)
                              Text(
                                _decodeHtmlEntities(widget.title),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade900,
                                  height: 1.3,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Timestamp detail
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimestamp(widget.timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Content Card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.article_rounded,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Message Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.grey.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.deepPurple.shade200,
                                    Colors.blue.shade200,
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildHtmlContent(widget.body, isDark),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                icon: const Icon(
                                    Icons.check_circle_outline_rounded),
                                label: const Text('Done'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple.shade600,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                  shadowColor:
                                      Colors.deepPurple.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
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

  Widget _buildHtmlContent(String content, bool isDark) {
    // Check if content looks like HTML
    final looksLikeHtml = content.contains('<') && content.contains('>');

    if (!looksLikeHtml) {
      // Plain text fallback with beautiful styling (decode entities including emojis)
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey.shade700.withOpacity(0.3)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: SelectableText(
          _decodeHtmlEntities(content),
          style: TextStyle(
            fontSize: 16,
            height: 1.7,
            color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    // Render HTML with beautiful flutter_html styling
    return Html(
      data: content,
      style: {
        "body": Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(16),
          lineHeight: const LineHeight(1.7),
          color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
          letterSpacing: 0.3,
        ),
        "p": Style(
          margin: Margins.only(bottom: 16),
          fontSize: FontSize(16),
        ),
        "h1": Style(
          fontSize: FontSize(26),
          fontWeight: FontWeight.bold,
          margin: Margins.only(bottom: 16, top: 12),
          color: isDark ? Colors.white : Colors.grey.shade900,
        ),
        "h2": Style(
          fontSize: FontSize(22),
          fontWeight: FontWeight.bold,
          margin: Margins.only(bottom: 14, top: 10),
          color: isDark ? Colors.white : Colors.grey.shade900,
        ),
        "h3": Style(
          fontSize: FontSize(19),
          fontWeight: FontWeight.w600,
          margin: Margins.only(bottom: 12, top: 8),
          color: isDark ? Colors.grey.shade100 : Colors.grey.shade800,
        ),
        "a": Style(
          color: Colors.blue.shade600,
          textDecoration: TextDecoration.underline,
          textDecorationColor: Colors.blue.shade300,
        ),
        "ul": Style(
          margin: Margins.only(left: 20, bottom: 16, top: 8),
        ),
        "ol": Style(
          margin: Margins.only(left: 20, bottom: 16, top: 8),
        ),
        "li": Style(
          margin: Margins.only(bottom: 8),
          fontSize: FontSize(16),
        ),
        "blockquote": Style(
          margin: Margins.only(left: 0, bottom: 16, top: 8),
          padding: HtmlPaddings.only(left: 16, top: 12, bottom: 12, right: 16),
          border: Border(
            left: BorderSide(
              color: isDark
                  ? Colors.deepPurple.shade400
                  : Colors.deepPurple.shade300,
              width: 4,
            ),
          ),
          backgroundColor: isDark
              ? Colors.deepPurple.shade900.withOpacity(0.2)
              : Colors.deepPurple.shade50,
        ),
        "code": Style(
          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          color: isDark ? Colors.lightGreen.shade300 : Colors.green.shade700,
          padding: HtmlPaddings.symmetric(horizontal: 6, vertical: 3),
          fontFamily: 'monospace',
          fontSize: FontSize(14),
        ),
        "pre": Style(
          backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
          padding: HtmlPaddings.all(16),
          margin: Margins.only(bottom: 16, top: 8),
          fontFamily: 'monospace',
          fontSize: FontSize(14),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        "img": Style(
          margin: Margins.only(bottom: 16, top: 8),
        ),
        "table": Style(
          margin: Margins.only(bottom: 16, top: 8),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        "th": Style(
          padding: HtmlPaddings.all(12),
          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          fontWeight: FontWeight.bold,
        ),
        "td": Style(
          padding: HtmlPaddings.all(12),
          border: Border.all(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        "strong": Style(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.grey.shade900,
        ),
        "em": Style(
          fontStyle: FontStyle.italic,
        ),
        "hr": Style(
          margin: Margins.symmetric(vertical: 20),
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 1,
            ),
          ),
        ),
      },
      onLinkTap: (url, _, __) {
        if (url != null) {
          _launchUrl(url);
        }
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Invalid URL'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.link_off, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Cannot open: $url')),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to open link')),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}
