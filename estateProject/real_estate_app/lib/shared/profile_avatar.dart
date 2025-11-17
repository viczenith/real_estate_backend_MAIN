import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String fallbackInitial;
  final double radius;
  final BoxFit fit;

  const ProfileAvatar({
    Key? key,
    required this.imageUrl,
    required this.fallbackInitial,
    this.radius = 20,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;
    if (hasUrl) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: fit,
            placeholder: (context, url) => Container(
              color: Colors.white24,
              child: Center(
                child: SizedBox(
                  width: radius,
                  height: radius,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            errorWidget: (context, url, error) => _assetOrInitial(),
          ),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: _assetOrInitial(),
      ),
    );
  }

  Widget _assetOrInitial() {
    return Image.asset(
      'assets/avatar.webp',
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.white24,
          alignment: Alignment.center,
          child: Text(
            fallbackInitial.isNotEmpty ? fallbackInitial[0].toUpperCase() : '?',
            style: TextStyle(color: Colors.white, fontSize: radius * 0.9),
          ),
        );
      },
    );
  }
}
