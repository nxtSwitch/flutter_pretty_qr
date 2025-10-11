import 'dart:math';

import 'package:flutter/painting.dart';

import 'package:pretty_qr_code/src/rendering/pretty_qr_painting_context.dart';

/// Extensions that apply to [Point<int>].
extension PrettyQrRectanglePaintExtension on Rectangle<int> {
  /// Convert this instance into a floating-point rectangle whose coordinates
  /// are relative to a given QR Symbol.
  @pragma('vm:prefer-inline')
  Rect resolveRect(PrettyQrPaintingContext context) {
    return Rect.fromLTRB(
      left * context.moduleDimension,
      top * context.moduleDimension,
      (left + width + 1) * context.moduleDimension,
      (top + height + 1) * context.moduleDimension,
    ).shift(context.estimatedBounds.topLeft);
  }
}
