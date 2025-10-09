import 'dart:ui';

import 'package:meta/meta.dart';

import 'package:pretty_qr_code/src/painting/pretty_qr_clipper.dart';

/// {@template pretty_qr_code.painting.PrettyQrRectangleClipper}
/// A base clipper for QR code embedded images.
/// {@endtemplate}
class PrettyQrRectangleClipper implements PrettyQrClipper {
  /// {@macro pretty_qr_code.painting.PrettyQrRectangleClipper}
  @literal
  const PrettyQrRectangleClipper();

  @override
  Path getClip(Size size) {
    return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
  }
}
