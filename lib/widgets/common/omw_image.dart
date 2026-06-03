import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Displays a network image from [url] at the given [width] x [height].
/// Shows [placeholder] while loading, on error, or when [url] is empty.
class OmwNetworkImage extends StatelessWidget {
  const OmwNetworkImage({
    super.key,
    required this.url,
    required this.placeholder,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 12.0,
  });

  final String url;
  final Widget placeholder;
  final double width;
  final double height;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url.trim();
    if (imageUrl.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            debugPrint('[OMW Image] Failed to render image: $imageUrl $error');
          }
          return placeholder;
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return placeholder;
        },
      ),
    );
  }
}
