import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart';

/// Result of object validation analysis (single mode).
class ObjectValidationResult {
  final ObjectValidation state;
  final double coverage;

  const ObjectValidationResult({required this.state, required this.coverage});
}

/// Object detection state based on pixel brightness analysis (single mode).
enum ObjectValidation {
  idle,
  noObject,
  ready,
  tooLarge,
}

/// Object detection state for mixed-waste mode.
enum MixedObjectValidation {
  idle,
  noObject,
  ready,
  tooManyObjects,
  objectsOverlapping,
  objectOutsideBoundary,
}

/// Result of mixed-mode validation.
class MixedValidationResult {
  final MixedObjectValidation state;
  final int objectCount;
  final double coverage;

  const MixedValidationResult({
    required this.state,
    required this.objectCount,
    required this.coverage,
  });
}

/// A detected object region with separate rects for display and classification.
class DetectedRegion {
  /// Bounding box for UI display borders (with small padding).
  final Rect displayRect;

  /// Padded + squared bounding box — for model classification input.
  final Rect classificationRect;

  const DetectedRegion({
    required this.displayRect,
    required this.classificationRect,
  });
}

/// Result of object region detection including image dimensions.
class DetectionResult {
  final List<DetectedRegion> regions;
  final int imageWidth;
  final int imageHeight;

  const DetectionResult({
    required this.regions,
    required this.imageWidth,
    required this.imageHeight,
  });
}

/// Analyzes camera frames to detect if an object (trash) is present
/// on a dark (black) board. Uses simple pixel luminance analysis:
/// bright pixels = object, dark pixels = background board.
class ObjectValidatorService {
  /// Max dimension for analysis. The image is resized maintaining aspect ratio
  /// so that the longer side equals this value. Higher = more precise borders.
  static const int _analysisMaxSize = 192;

  /// Luminance threshold — pixels brighter than this are considered "object".
  static const int _luminanceThreshold = 120;

  /// Boundary region is the center percentage of the resized image.
  static const double _boundaryFraction = 0.92;

  /// Coverage thresholds (single mode).
  static const double _noObjectThreshold = 0.05;
  static const double _tooLargeThreshold = 0.65;

  /// Max objects for mixed mode.
  static const int _maxObjects = 5;

  /// Minimum cluster area (pixels in analysis grid) to count as a real object.
  static const int _minClusterArea = 80;

  /// Overlap threshold — if a single cluster covers more than this fraction
  /// of the boundary area, it is likely overlapping objects.
  static const double _overlapClusterThreshold = 0.30;

  /// Fraction of a cluster's pixels that must be outside boundary to trigger
  /// OBJECT_OUTSIDE_BOUNDARY.
  static const double _outsideBoundaryRatio = 0.30;

  /// Display rect padding factor — adds this fraction of cluster size as
  /// padding to the display bounding box to ensure objects are fully enclosed.
  static const double _displayPadding = 0.10;

  /// Decode JPEG, resize maintaining aspect ratio, blur, and threshold.
  /// Returns (analysisWidth, analysisHeight, binaryGrid, originalImage).
  (int, int, List<List<bool>>, Image?) _buildAnalysis(Uint8List jpegBytes) {
    final image = decodeImage(jpegBytes);
    if (image == null) {
      return (0, 0, [], null);
    }

    final origW = image.width;
    final origH = image.height;

    // Resize maintaining aspect ratio
    final int aw, ah;
    if (origW >= origH) {
      aw = _analysisMaxSize;
      ah = (origH * _analysisMaxSize / origW).round().clamp(1, _analysisMaxSize);
    } else {
      ah = _analysisMaxSize;
      aw = (origW * _analysisMaxSize / origH).round().clamp(1, _analysisMaxSize);
    }

    final small = copyResize(image, width: aw, height: ah);

    // Gaussian blur to smooth camera noise before thresholding
    final blurred = gaussianBlur(small, radius: 2);

    final binary = List.generate(ah, (_) => List.filled(aw, false));
    for (int y = 0; y < ah; y++) {
      for (int x = 0; x < aw; x++) {
        final pixel = blurred.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
        binary[y][x] = luminance > _luminanceThreshold;
      }
    }

    return (aw, ah, binary, image);
  }

  /// Validate a JPEG frame for object presence (single mode).
  Future<ObjectValidationResult> validate(
    Uint8List jpegBytes, {
    Rect? region,
  }) async {
    final (aw, ah, binary, origImage) = _buildAnalysis(jpegBytes);
    if (binary.isEmpty || origImage == null) {
      return const ObjectValidationResult(
        state: ObjectValidation.idle,
        coverage: 0,
      );
    }

    // Define boundary region (center 92%)
    final marginX = (aw * (1 - _boundaryFraction) / 2).round();
    final marginY = (ah * (1 - _boundaryFraction) / 2).round();
    final x0 = marginX;
    final y0 = marginY;
    final x1 = aw - marginX;
    final y1 = ah - marginY;

    // Count bright pixels inside the boundary
    int brightPixels = 0;
    int totalPixels = 0;

    for (int y = y0; y < y1; y++) {
      for (int x = x0; x < x1; x++) {
        if (binary[y][x]) {
          brightPixels++;
        }
        totalPixels++;
      }
    }

    if (totalPixels == 0) {
      return const ObjectValidationResult(
        state: ObjectValidation.idle,
        coverage: 0,
      );
    }

    final coverage = brightPixels / totalPixels;

    ObjectValidation state;
    if (coverage < _noObjectThreshold) {
      state = ObjectValidation.noObject;
    } else if (coverage > _tooLargeThreshold) {
      state = ObjectValidation.tooLarge;
    } else {
      state = ObjectValidation.ready;
    }

    return ObjectValidationResult(state: state, coverage: coverage);
  }

  /// Validate a JPEG frame for mixed-waste mode.
  ///
  /// Performs connected component analysis on the resized image:
  /// 1. Binary threshold (luminance > [_luminanceThreshold])
  /// 2. BFS flood fill to label connected bright regions
  /// 3. Determine state based on cluster count, area, and boundary
  Future<MixedValidationResult> validateMixed(Uint8List jpegBytes) async {
    final (aw, ah, binary, origImage) = _buildAnalysis(jpegBytes);
    if (binary.isEmpty || origImage == null) {
      return const MixedValidationResult(
        state: MixedObjectValidation.idle,
        objectCount: 0,
        coverage: 0,
      );
    }

    // Define boundary region (center 92%)
    final marginX = (aw * (1 - _boundaryFraction) / 2).round();
    final marginY = (ah * (1 - _boundaryFraction) / 2).round();
    final bx0 = marginX;
    final by0 = marginY;
    final bx1 = aw - marginX;
    final by1 = ah - marginY;
    final boundaryArea = (bx1 - bx0) * (by1 - by0);

    // Connected component analysis via BFS flood fill
    final labels = List.generate(ah, (_) => List.filled(aw, -1));
    final allClusters = <_Cluster>[];
    int currentLabel = 0;

    for (int y = 0; y < ah; y++) {
      for (int x = 0; x < aw; x++) {
        if (binary[y][x] && labels[y][x] == -1) {
          final cluster = _bfs(binary, labels, x, y, currentLabel, aw, ah);
          allClusters.add(cluster);
          currentLabel++;
        }
      }
    }

    // Filter out noise clusters that are too small to be real objects
    final clusters = allClusters.where((c) => c.area >= _minClusterArea).toList();

    // Total bright pixel coverage inside boundary
    int brightInBoundary = 0;
    for (int y = by0; y < by1; y++) {
      for (int x = bx0; x < bx1; x++) {
        if (binary[y][x]) brightInBoundary++;
      }
    }
    final coverage = boundaryArea > 0 ? brightInBoundary / boundaryArea : 0.0;

    // Count bright pixels outside boundary
    int brightOutsideBoundary = 0;
    for (final cluster in clusters) {
      if (cluster.minX < bx0 ||
          cluster.maxX >= bx1 ||
          cluster.minY < by0 ||
          cluster.maxY >= by1) {
        brightOutsideBoundary += _countOutsideBoundary(
          cluster,
          labels,
          bx0,
          by0,
          bx1,
          by1,
        );
      }
    }

    // State determination
    if (coverage < _noObjectThreshold) {
      return MixedValidationResult(
        state: MixedObjectValidation.noObject,
        objectCount: 0,
        coverage: coverage,
      );
    }

    if (clusters.length > _maxObjects) {
      return MixedValidationResult(
        state: MixedObjectValidation.tooManyObjects,
        objectCount: clusters.length,
        coverage: coverage,
      );
    }

    if (brightOutsideBoundary > 0) {
      int outsideClusterCount = 0;
      for (final cluster in clusters) {
        final outside = _countOutsideBoundary(cluster, labels, bx0, by0, bx1, by1);
        if (outside > 0 && (outside / cluster.area) > _outsideBoundaryRatio) {
          outsideClusterCount++;
        }
      }
      if (outsideClusterCount > 0) {
        return MixedValidationResult(
          state: MixedObjectValidation.objectOutsideBoundary,
          objectCount: outsideClusterCount,
          coverage: coverage,
        );
      }
    }

    // Check for overlapping
    for (final cluster in clusters) {
      final clusterRatio = cluster.area / boundaryArea;
      if (clusterRatio > _overlapClusterThreshold) {
        return MixedValidationResult(
          state: MixedObjectValidation.objectsOverlapping,
          objectCount: clusters.length,
          coverage: coverage,
        );
      }
    }

    return MixedValidationResult(
      state: MixedObjectValidation.ready,
      objectCount: clusters.length,
      coverage: coverage,
    );
  }

  /// Build a DetectedRegion from a cluster, scaling from analysis coords
  /// to original image coordinates.
  DetectedRegion _buildRegion(_Cluster cluster, int aw, int ah, int origW, int origH) {
    final scaleX = origW / aw;
    final scaleY = origH / ah;
    final clusterW = (cluster.maxX - cluster.minX + 1).toDouble();
    final clusterH = (cluster.maxY - cluster.minY + 1).toDouble();

    // Display rect with padding — for UI borders
    final dPadX = (clusterW * _displayPadding).round();
    final dPadY = (clusterH * _displayPadding).round();

    final dispLeft = ((cluster.minX - dPadX) * scaleX).clamp(0.0, origW - 1.0);
    final dispTop = ((cluster.minY - dPadY) * scaleY).clamp(0.0, origH - 1.0);
    final dispRight = ((cluster.maxX + 1 + dPadX) * scaleX).clamp(0.0, origW - 1.0);
    final dispBottom = ((cluster.maxY + 1 + dPadY) * scaleY).clamp(0.0, origH - 1.0);
    final displayRect = Rect.fromLTRB(dispLeft, dispTop, dispRight, dispBottom);

    // Classification rect (20% padding + squared) — for model input
    const cPadding = 0.20;
    final cPadX = (clusterW * cPadding).round();
    final cPadY = (clusterH * cPadding).round();

    var left = ((cluster.minX - cPadX) * scaleX).round().clamp(0, origW - 1);
    var top = ((cluster.minY - cPadY) * scaleY).round().clamp(0, origH - 1);
    var right = ((cluster.maxX + cPadX) * scaleX).round().clamp(0, origW - 1);
    var bottom = ((cluster.maxY + cPadY) * scaleY).round().clamp(0, origH - 1);

    // Make the crop square (model expects square input)
    final cropW = right - left;
    final cropH = bottom - top;
    if (cropW > cropH) {
      final expand = (cropW - cropH) ~/ 2;
      top = (top - expand).clamp(0, origH - 1);
      bottom = (bottom + expand).clamp(0, origH - 1);
    } else if (cropH > cropW) {
      final expand = (cropH - cropW) ~/ 2;
      left = (left - expand).clamp(0, origW - 1);
      right = (right + expand).clamp(0, origW - 1);
    }

    final paddedRect = right > left && bottom > top
        ? Rect.fromLTRB(left.toDouble(), top.toDouble(), right.toDouble(), bottom.toDouble())
        : displayRect;

    return DetectedRegion(
      displayRect: displayRect,
      classificationRect: paddedRect,
    );
  }

  /// Detect individual object regions in a full-resolution image.
  ///
  /// Returns a [DetectionResult] with regions sorted by size descending and
  /// the correctly oriented image dimensions (accounting for EXIF rotation).
  Future<DetectionResult> detectObjectRegions(Uint8List jpegBytes) async {
    final (aw, ah, binary, origImage) = _buildAnalysis(jpegBytes);
    if (binary.isEmpty || origImage == null) {
      return const DetectionResult(regions: [], imageWidth: 0, imageHeight: 0);
    }

    final origW = origImage.width;
    final origH = origImage.height;

    // Connected component analysis
    final labels = List.generate(ah, (_) => List.filled(aw, -1));
    final allClusters = <_Cluster>[];
    int currentLabel = 0;

    for (int y = 0; y < ah; y++) {
      for (int x = 0; x < aw; x++) {
        if (binary[y][x] && labels[y][x] == -1) {
          final cluster = _bfs(binary, labels, x, y, currentLabel, aw, ah);
          allClusters.add(cluster);
          currentLabel++;
        }
      }
    }

    // Filter noise and take up to 5 clusters, sorted by area desc
    final clusters = allClusters
        .where((c) => c.area >= _minClusterArea)
        .toList()
      ..sort((a, b) => b.area.compareTo(a.area));

    final regions = clusters
        .take(_maxObjects)
        .map((c) => _buildRegion(c, aw, ah, origW, origH))
        .toList();

    return DetectionResult(
      regions: regions,
      imageWidth: origW,
      imageHeight: origH,
    );
  }

  /// BFS flood fill to label a connected bright region.
  static _Cluster _bfs(
    List<List<bool>> binary,
    List<List<int>> labels,
    int startX,
    int startY,
    int label,
    int width,
    int height,
  ) {
    final queue = Queue<List<int>>();
    queue.add([startX, startY]);
    labels[startY][startX] = label;

    int area = 0;
    int minX = startX, maxX = startX;
    int minY = startY, maxY = startY;

    while (queue.isNotEmpty) {
      final point = queue.removeFirst();
      final x = point[0];
      final y = point[1];
      area++;

      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;

      // 4-connected neighbors
      for (final dir in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
        final nx = x + dir[0];
        final ny = y + dir[1];
        if (nx >= 0 &&
            nx < width &&
            ny >= 0 &&
            ny < height &&
            binary[ny][nx] &&
            labels[ny][nx] == -1) {
          labels[ny][nx] = label;
          queue.add([nx, ny]);
        }
      }
    }

    return _Cluster(
      label: label,
      area: area,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );
  }

  /// Count pixels of a cluster that fall outside the boundary region.
  static int _countOutsideBoundary(
    _Cluster cluster,
    List<List<int>> labels,
    int bx0,
    int by0,
    int bx1,
    int by1,
  ) {
    int count = 0;
    final startX = cluster.minX < bx0 ? cluster.minX : bx0;
    final endX = cluster.maxX >= bx1 ? cluster.maxX : bx1 - 1;
    final startY = cluster.minY < by0 ? cluster.minY : by0;
    final endY = cluster.maxY >= by1 ? cluster.maxY : by1 - 1;

    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        if (y >= 0 &&
            y < labels.length &&
            x >= 0 &&
            x < labels[0].length &&
            labels[y][x] == cluster.label) {
          if (x < bx0 || x >= bx1 || y < by0 || y >= by1) {
            count++;
          }
        }
      }
    }
    return count;
  }
}

/// Internal representation of a connected component cluster.
class _Cluster {
  final int label;
  final int area;
  final int minX;
  final int minY;
  final int maxX;
  final int maxY;

  const _Cluster({
    required this.label,
    required this.area,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });
}
