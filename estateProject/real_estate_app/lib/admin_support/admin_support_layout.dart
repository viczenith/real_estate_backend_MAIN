import 'package:flutter/material.dart';
import 'package:real_estate_app/shared/app_layout.dart';
import 'package:real_estate_app/shared/app_side.dart';

/// Wrapper layout for all Admin Support pages.
/// Reuses the shared AppLayout so we get the same header/sidebar behaviour.
class AdminSupportLayout extends StatelessWidget {
  final Widget child;
  final String pageTitle;
  final String token;

  const AdminSupportLayout({
    super.key,
    required this.child,
    required this.pageTitle,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      child: child,
      pageTitle: pageTitle,
      token: token,
      side: AppSide.adminSupport,
    );
  }
}
