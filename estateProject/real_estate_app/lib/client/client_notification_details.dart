import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:real_estate_app/core/api_service.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class NotificationDetailPage extends StatefulWidget {
  final String token;
  final int userNotificationId;
  const NotificationDetailPage({
    required this.token,
    required this.userNotificationId,
    super.key,
  });

  @override
  _NotificationDetailPageState createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  final ApiService _api = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _userNotification;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = widget.token.trim();
    if (token.isEmpty) {
      setState(() {
        _error = 'Not authenticated.';
        _loading = false;
      });
      return;
    }

    try {
      final data = await _api.getClientNotificationDetail(
        token: token,
        userNotificationId: widget.userNotificationId,
      );
      if (!mounted) return;
      setState(() => _userNotification = Map<String, dynamic>.from(data));
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Unexpected error');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead() async {
    if (_userNotification == null) return;
    final id = _userNotification!['id'] as int? ?? -1;
    if (id < 0) return;

    try {
      await _api.markClientNotificationRead(token: widget.token, userNotificationId: id);
      if (!mounted) return;
      setState(() {
        _userNotification = {..._userNotification!, 'read': true};
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Marked as read')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fix status bar
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text(
          'Notification Details',
          style: TextStyle(
            color: Color(0xFF1a1a1a),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1a1a1a),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4154F1),
                  strokeWidth: 3,
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red.shade400,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Failed to load',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4154F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Sticky Header
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _NotificationHeaderDelegate(
                          child: Container(
                            color: const Color(0xFFF6F8FB),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF4154F1).withOpacity(0.1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
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
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4154F1).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_rounded,
                                      color: Color(0xFF4154F1),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _userNotification?['notification']?['title']?.toString() ?? 'Notification',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1a1a1a),
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule,
                                              size: 14,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                _getFormattedDate(),
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _userNotification?['read'] == true
                                          ? Colors.grey.shade100
                                          : const Color(0xFF4154F1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _userNotification?['read'] == true
                                              ? Icons.check_circle
                                              : Icons.circle,
                                          size: 12,
                                          color: _userNotification?['read'] == true
                                              ? Colors.grey.shade600
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _userNotification?['read'] == true ? 'Read' : 'New',
                                          style: TextStyle(
                                            color: _userNotification?['read'] == true
                                                ? Colors.grey.shade600
                                                : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          minHeight: 130,
                          maxHeight: 130,
                        ),
                      ),

                      // Message Card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Message',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildMessageContent(),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Action Button
                      // if (_userNotification?['read'] != true)
                      //   SliverToBoxAdapter(
                      //     child: Padding(
                      //       padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      //       child: ElevatedButton.icon(
                      //         onPressed: _markRead,
                      //         icon: const Icon(
                      //           Icons.check_circle_rounded,
                      //           size: 20,
                      //         ),
                      //         label: const Text('Mark as Read'),
                      //         style: ElevatedButton.styleFrom(
                      //           padding: const EdgeInsets.symmetric(
                      //               vertical: 16, horizontal: 24),
                      //           shape: RoundedRectangleBorder(
                      //             borderRadius: BorderRadius.circular(12),
                      //           ),
                      //           backgroundColor: const Color(0xFF4154F1),
                      //           foregroundColor: Colors.white,
                      //           elevation: 0,
                      //         ),
                      //       ),
                      //     ),
                      //   ),
                    ],
                  ),
      ),
    );
  }

  String _getFormattedDate() {
    try {
      final createdAt = _userNotification?['notification']?['created_at']?.toString() ?? 
                       _userNotification?['created_at']?.toString() ?? '';
      if (createdAt.isEmpty) return 'Unknown date';
      
      final date = DateTime.parse(createdAt);
      return DateFormat('MMMM d, yyyy • h:mm a').format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _decodeHtmlEntities(String text) {
    // Comprehensive HTML entity decoding for accurate symbol display
    return text
        // Common entities
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        // Currency symbols
        .replaceAll('&euro;', '€')
        .replaceAll('&#8364;', '€')
        .replaceAll('&pound;', '£')
        .replaceAll('&#163;', '£')
        .replaceAll('&yen;', '¥')
        .replaceAll('&#165;', '¥')
        .replaceAll('&cent;', '¢')
        .replaceAll('&#162;', '¢')
        .replaceAll('&#8358;', '₦') // Naira symbol
        // Math symbols
        .replaceAll('&times;', '×')
        .replaceAll('&#215;', '×')
        .replaceAll('&divide;', '÷')
        .replaceAll('&#247;', '÷')
        .replaceAll('&plusmn;', '±')
        .replaceAll('&#177;', '±')
        .replaceAll('&ne;', '≠')
        .replaceAll('&#8800;', '≠')
        .replaceAll('&le;', '≤')
        .replaceAll('&#8804;', '≤')
        .replaceAll('&ge;', '≥')
        .replaceAll('&#8805;', '≥')
        // Arrows
        .replaceAll('&larr;', '←')
        .replaceAll('&#8592;', '←')
        .replaceAll('&rarr;', '→')
        .replaceAll('&#8594;', '→')
        .replaceAll('&uarr;', '↑')
        .replaceAll('&#8593;', '↑')
        .replaceAll('&darr;', '↓')
        .replaceAll('&#8595;', '↓')
        // Punctuation
        .replaceAll('&mdash;', '—')
        .replaceAll('&#8212;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&#8211;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&#8230;', '…')
        .replaceAll('&lsquo;', ''')
        .replaceAll('&#8216;', ''')
        .replaceAll('&rsquo;', ''')
        .replaceAll('&#8217;', ''')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&#8220;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&bull;', '•')
        .replaceAll('&#8226;', '•')
        // Special symbols
        .replaceAll('&copy;', '©')
        .replaceAll('&#169;', '©')
        .replaceAll('&reg;', '®')
        .replaceAll('&#174;', '®')
        .replaceAll('&trade;', '™')
        .replaceAll('&#8482;', '™')
        .replaceAll('&deg;', '°')
        .replaceAll('&#176;', '°')
        .replaceAll('&para;', '¶')
        .replaceAll('&#182;', '¶')
        .replaceAll('&sect;', '§')
        .replaceAll('&#167;', '§')
        // Accented characters
        .replaceAll('&agrave;', 'à')
        .replaceAll('&aacute;', 'á')
        .replaceAll('&acirc;', 'â')
        .replaceAll('&atilde;', 'ã')
        .replaceAll('&auml;', 'ä')
        .replaceAll('&aring;', 'å')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&egrave;', 'è')
        .replaceAll('&ecirc;', 'ê')
        .replaceAll('&euml;', 'ë')
        .replaceAll('&iacute;', 'í')
        .replaceAll('&igrave;', 'ì')
        .replaceAll('&icirc;', 'î')
        .replaceAll('&iuml;', 'ï')
        .replaceAll('&oacute;', 'ó')
        .replaceAll('&ograve;', 'ò')
        .replaceAll('&ocirc;', 'ô')
        .replaceAll('&otilde;', 'õ')
        .replaceAll('&ouml;', 'ö')
        .replaceAll('&uacute;', 'ú')
        .replaceAll('&ugrave;', 'ù')
        .replaceAll('&ucirc;', 'û')
        .replaceAll('&uuml;', 'ü')
        .replaceAll('&ntilde;', 'ñ')
        .replaceAll('&ccedil;', 'ç');
  }

  String _preprocessHtml(String html) {
    // Ensure proper HTML structure and decode entities
    String processed = html;
    
    // Wrap plain text in paragraph if no HTML structure
    if (!processed.contains('<p>') && !processed.contains('<div>') && !processed.contains('<br>')) {
      processed = '<p>$processed</p>';
    }
    
    // Fix common HTML issues
    processed = processed
        .replaceAll('\n\n', '<br><br>')  // Double newlines to breaks
        .replaceAll('\n', '<br>')        // Single newlines to breaks
        .trim();
    
    return processed;
  }

  bool _hasComplexInlineStyles(String html) {
    // Check if HTML contains complex CSS that flutter_html can't handle
    return html.contains('linear-gradient') ||
        html.contains('box-shadow') ||
        html.contains('transform') ||
        html.contains('background: ') && html.contains('gradient') ||
        (html.contains('style="') && html.split('style="').length > 5); // Many inline styles
  }

  Widget _buildWebViewHtml(String html) {
    // Wrap HTML in a complete document with proper viewport and UTF-8 encoding
    final wrappedHtml = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <style>
        body {
            margin: 0;
            padding: 16px;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            font-size: 15px;
            line-height: 1.6;
            color: #1a1a1a;
            background-color: #ffffff;
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        * {
            max-width: 100%;
        }
        img {
            height: auto !important;
            display: block;
            margin: 8px 0;
        }
        a {
            color: #4154F1;
            text-decoration: underline;
        }
    </style>
</head>
<body>
$html
</body>
</html>
''';

    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (NavigationRequest request) {
              // Handle link clicks - open in external browser
              if (request.url.startsWith('http')) {
                launchUrl(Uri.parse(request.url), mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadHtmlString(wrappedHtml);

      return SizedBox(
        height: 500, // Adjust based on content
        child: WebViewWidget(controller: controller),
      );
    } catch (e) {
      // Fallback to flutter_html if WebView fails
      print('⚠️ WebView not available, falling back to flutter_html: $e');
      return _buildFlutterHtml(html);
    }
  }

  Widget _buildFlutterHtml(String html) {
    return Html(
      data: html,
      shrinkWrap: true,
      style: {
        'body': Style(
          color: const Color(0xFF1a1a1a),
          fontSize: FontSize(15),
          lineHeight: const LineHeight(1.6),
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        'div': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.all(12),
        ),
        'p': Style(
          margin: Margins.only(bottom: 12),
          color: const Color(0xFF1a1a1a),
        ),
        'h1': Style(
          fontSize: FontSize(22),
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1a1a1a),
          margin: Margins.only(top: 16, bottom: 12),
        ),
        'h2': Style(
          fontSize: FontSize(20),
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1a1a1a),
          margin: Margins.only(top: 14, bottom: 10),
        ),
        'h3': Style(
          fontSize: FontSize(18),
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1a1a1a),
          margin: Margins.only(top: 12, bottom: 8),
        ),
        'a': Style(
          color: const Color(0xFF4154F1),
          textDecoration: TextDecoration.underline,
        ),
      },
      onLinkTap: (url, _, __) {
        if (url != null) {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  Widget _buildMessageContent() {
    final message = _userNotification?['notification']?['message']?.toString() ?? 'No message content';
    
    // Check if content looks like HTML
    if (message.contains('<') && message.contains('>')) {
      // Use WebView for complex HTML with inline styles
      if (_hasComplexInlineStyles(message)) {
        return _buildWebViewHtml(message);
      }
      
      // Use flutter_html for simpler HTML
      try {
        // Preprocess HTML for better rendering
        final processedHtml = _preprocessHtml(message);
        return _buildFlutterHtml(processedHtml);
      } catch (e) {
        // Fallback to plain text
        return SelectableText(
          _decodeHtmlEntities(message),
          style: const TextStyle(
            color: Color(0xFF1a1a1a),
            fontSize: 15,
            height: 1.6,
            fontFamily: 'Roboto',
          ),
        );
      }
    } else {
      // Plain text content with entity decoding and emoji support
      return SelectableText(
        _decodeHtmlEntities(message),
        style: const TextStyle(
          color: Color(0xFF1a1a1a),
          fontSize: 15,
          height: 1.6,
          fontFamily: 'Roboto',
        ),
      );
    }
  }
}

/// Sticky header delegate for notification detail header
class _NotificationHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _NotificationHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_NotificationHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

