import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders one of the branding logo assets exposed by [BrandingController].
///
/// White-label configs may point at either a vector (`.svg`) or a raster
/// (`.png`/`.jpg`) file, so the renderer is picked from the file extension.
class BrandLogo extends StatelessWidget {
  const BrandLogo(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  /// Asset path, e.g. `assets/images/guardify-round-white.png`.
  final String asset;

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (asset.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(asset, width: width, height: height, fit: fit);
    }
    return Image.asset(asset, width: width, height: height, fit: fit);
  }
}
