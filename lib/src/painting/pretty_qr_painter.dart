import 'dart:math';

import 'package:meta/meta.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';

import 'package:pretty_qr_code/src/base/pretty_qr_matrix.dart';

import 'package:pretty_qr_code/src/rendering/pretty_qr_painting_context.dart';
import 'package:pretty_qr_code/src/rendering/pretty_qr_render_capabilities.dart';

import 'package:pretty_qr_code/src/painting/pretty_qr_brush.dart';
import 'package:pretty_qr_code/src/painting/decoration/pretty_qr_decoration.dart';
import 'package:pretty_qr_code/src/painting/decoration/pretty_qr_decoration_image.dart';
import 'package:pretty_qr_code/src/painting/extensions/pretty_qr_module_extensions.dart';
import 'package:pretty_qr_code/src/painting/extensions/pretty_qr_quiet_zone_extension.dart';

/// A stateful class that can paint a QR code.
///
/// To obtain a painter, call [PrettyQrDecoration.createPainter].
@internal
class PrettyQrPainter {
  /// Callback that is invoked if an asynchronously-loading resource used by the
  /// decoration finishes loading. For example, an image. When this is invoked,
  /// the [paint] method should be called again.
  @nonVirtual
  final VoidCallback onChanged;

  /// What decoration to paint.
  @nonVirtual
  final PrettyQrDecoration decoration;

  /// The QR code clipped matrix cache.
  @protected
  PrettyQrMatrix? _clippedMatrix;

  /// The painter for a [PrettyQrDecorationImage].
  @protected
  DecorationImagePainter? _decorationImagePainter;

  /// Creates a QR code painter.
  PrettyQrPainter({
    required this.onChanged,
    required this.decoration,
  });

  /// Draw the QR code image onto the given canvas.
  @nonVirtual
  void paint(
    final PrettyQrPaintingContext context,
    final ImageConfiguration configuration,
  ) {
    final background = decoration.background;
    if (background != null) {
      final backgroundBrush = PrettyQrBrush.from(background);
      context.canvas.drawRect(
        context.estimatedBounds,
        backgroundBrush.toPaint(
          context.estimatedBounds,
          textDirection: context.textDirection,
        ),
      );
    }

    final quietZone = decoration.quietZone.resolveWidth(context);
    if (quietZone > 0) {
      context.canvas.translate(quietZone, quietZone);
      context.canvas.scale(1 - quietZone * 2 / context.boundsDimension);
    }

    final image = decoration.image;
    final size = context.estimatedBounds.size;

    if (image == null) {
      decoration.shape.paint(context);
      return;
    }

    if (image.position == PrettyQrDecorationImagePosition.foreground) {
      decoration.shape.paint(context);
    }

    final imageScale = image.scale.clamp(0.0, 1.0);
    final imageScaledRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * imageScale,
      height: size.height * imageScale,
    );

    final imagePadding = (image.padding * imageScale).resolve(
      configuration.textDirection,
    );
    final imageCroppedRect = imagePadding.deflateRect(imageScaledRect);

    final imageClipPath = image.clipper.getClip(imageScaledRect.size);
    final imageClipTransform = Matrix4.identity()
      ..translate(
        imageCroppedRect.topLeft.dx,
        imageCroppedRect.topLeft.dy,
      )
      ..scale(
        imageCroppedRect.width / imageScaledRect.width,
        imageCroppedRect.height / imageScaledRect.height,
      );

    _decorationImagePainter ??= image.createPainter(onChanged);
    _decorationImagePainter?.paint(
      context.canvas,
      imageCroppedRect,
      imageClipPath.transform(imageClipTransform.storage),
      configuration.copyWith(size: imageCroppedRect.size),
    );

    switch (image.position) {
      case PrettyQrDecorationImagePosition.foreground:
        break; // the QR code is already drawn
      case PrettyQrDecorationImagePosition.background:
        decoration.shape.paint(context);
        return;
      case PrettyQrDecorationImagePosition.embedded:
        try {
          _clippedMatrix ??= _prepareMatrix(
            context,
            clippedPath: imageClipPath.shift(imageScaledRect.topLeft),
          );
          decoration.shape.paint(context.copyWith(matrix: _clippedMatrix));
        } on Object catch (error, stackTrace) {
          decoration.shape.paint(context);
          assert(() {
            FlutterError.reportError(
              FlutterErrorDetails(
                silent: true,
                stack: stackTrace,
                exception: error,
                library: 'pretty qr code',
                context: ErrorDescription('while embedding image into qr code'),
              ),
            );
            return true;
          }());
        }
    }
  }

  @protected
  PrettyQrMatrix _prepareMatrix(
    final PrettyQrPaintingContext context, {
    required Path clippedPath,
  }) {
    final clippedRect = clippedPath.getBounds();
    final clippedBounds = Rectangle.fromPoints(
      Point(
        clippedRect.left / context.moduleDimension ~/ 1,
        clippedRect.top / context.moduleDimension ~/ 1,
      ),
      Point(
        clippedRect.right / context.moduleDimension ~/ 1,
        clippedRect.bottom / context.moduleDimension ~/ 1,
      ),
    );

    final excludedPoints = <Point>{};
    if (PrettyQrRenderCapabilities.enableClipperForNestedImage) {
      final clippedMatrixPath = Path.combine(
        PathOperation.difference,
        Path()..addRect(context.estimatedBounds),
        clippedPath,
      );

      for (final module in context.matrix) {
        if (!clippedBounds.containsPoint(module)) {
          continue;
        }

        final intersectModulePath = Path.combine(
          PathOperation.reverseDifference,
          clippedMatrixPath,
          module.resolvePath(context),
        );

        if (intersectModulePath.getBounds().isEmpty) continue;
        // ignore: avoid-ignoring-return-values, doesn't matter.
        excludedPoints.add(module.position);
      }
    } else {
      for (final module in context.matrix) {
        if (!clippedBounds.containsPoint(module)) continue;
        // ignore: avoid-ignoring-return-values, doesn't matter.
        excludedPoints.add(module.position);
      }
    }

    return PrettyQrMatrix.masked(
      context.matrix,
      excludePoints: excludedPoints,
    );
  }

  /// Discard any resources being held by the object.
  @mustCallSuper
  void dispose() {
    _clippedMatrix = null;
    _decorationImagePainter?.dispose();
    _decorationImagePainter = null;
  }
}
