import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_config.dart';
import 'option_b_gmaps_js_ready.dart';

const Color _mapBgTop = Color(0xFFE8F1F7);
const Color _mapBgBottom = Color(0xFFD8E7F0);
const Color _accentBlue = Color(0xFF1565C0);
const Color _accentYellow = Color(0xFFFFD000);

const bool kUseGoogleMaps = AppConfig.useGoogleMaps;

class DemoMapPoint {
  const DemoMapPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  static DemoMapPoint lerp(DemoMapPoint a, DemoMapPoint b, double t) {
    return DemoMapPoint(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }
}

class DemoMapMarker {
  const DemoMapMarker({
    required this.id,
    required this.point,
    required this.label,
    required this.icon,
  });

  final String id;
  final DemoMapPoint point;
  final String label;
  final IconData icon;
}

class AppMap extends StatefulWidget {
  const AppMap({
    super.key,
    required this.pickup,
    this.destination,
    this.driver,
    this.offerMarkers = const [],
    this.selectedMarkerId,
    this.onMarkerTap,
    this.onMapTap,
    this.routePoints = const [],
    this.cameraUpdateKey = 0,
    this.height,
    this.padding = EdgeInsets.zero,
    this.showRoute = false,
    // Set to false when the map is embedded in a scrollable page so that
    // touch/scroll gestures pass through to the parent scroll view instead
    // of panning/zooming the map unintentionally.
    this.gesturesEnabled = true,
  });

  final DemoMapPoint pickup;
  final DemoMapPoint? destination;
  final DemoMapPoint? driver;
  final List<DemoMapMarker> offerMarkers;
  final String? selectedMarkerId;
  final ValueChanged<String>? onMarkerTap;
  final ValueChanged<DemoMapPoint>? onMapTap;
  final List<DemoMapPoint> routePoints;
  final int cameraUpdateKey;
  final double? height;
  final EdgeInsets padding;
  final bool showRoute;
  final bool gesturesEnabled;

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  /// On web, the Maps JS API may load after the first Flutter frame; wait before
  /// building [GoogleMap], otherwise the map stays blank. On other platforms, or
  /// when the script never appears, fall back to the fake map.
  bool _webGmapsCheckDone = false;
  bool _webGmapsReady = false;
  String _webGmapsReason = 'Loading map';

  @override
  void initState() {
    super.initState();
    if (kIsWeb && kUseGoogleMaps) {
      optionBWaitForGmapsJsReady().then((_) {
        if (!mounted) return;
        setState(() {
          _webGmapsCheckDone = true;
          _webGmapsReady = optionBGmapsJsReady();
          _webGmapsReason = optionBGmapsStatusReason();
        });
      });
    } else {
      _webGmapsCheckDone = true;
      _webGmapsReady = true;
      _webGmapsReason = kUseGoogleMaps
          ? 'native map platform'
          : 'Map not configured';
    }
  }

  bool get _canUseGoogleMap =>
      kUseGoogleMaps && (!kIsWeb || (_webGmapsCheckDone && _webGmapsReady));

  bool get _isLoadingGoogleMap =>
      kUseGoogleMaps && kIsWeb && !_webGmapsCheckDone;

  @override
  void didUpdateWidget(covariant AppMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cameraUpdateKey != oldWidget.cameraUpdateKey ||
        widget.pickup != oldWidget.pickup ||
        widget.destination != oldWidget.destination ||
        widget.offerMarkers.length != oldWidget.offerMarkers.length ||
        widget.selectedMarkerId != oldWidget.selectedMarkerId) {
      _moveCameraToVisibleMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _canUseGoogleMap
        ? _mapWithStatusLabel(
            child: _googleMap(),
            label: 'Google Maps active',
            icon: Icons.map_outlined,
          )
        : _fallbackMap(
            label: _isLoadingGoogleMap ? 'Loading map…' : 'Map preview',
            reason: _fallbackReason,
          );

    if (!widget.gesturesEnabled) {
      // IgnorePointer is the critical web fix:
      // On Flutter Web it sets pointer-events:none on the underlying
      // HtmlElementView so the browser stops routing scroll/touch events to
      // the map element — they fall through to the parent ScrollView instead.
      // On native it bypasses Flutter's hit-testing for the same effect.
      // The GoogleMap gesture flags (scrollGesturesEnabled etc.) set earlier
      // are kept as belt-and-suspenders but are insufficient alone on web.
      child = Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(child: child),
          // Subtle label so users know the map is a non-interactive preview.
          const Positioned(right: 8, bottom: 8, child: _MapPreviewBadge()),
        ],
      );
    }

    if (widget.height == null) {
      return child;
    }
    return SizedBox(height: widget.height, child: child);
  }

  Widget _googleMap() {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: widget.pickup.latLng,
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
      if (widget.destination != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: widget.destination!.latLng,
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      if (widget.driver != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: widget.driver!.latLng,
          infoWindow: const InfoWindow(title: 'Driver'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      ...widget.offerMarkers.map((marker) {
        final selected = widget.selectedMarkerId == marker.id;
        return Marker(
          markerId: MarkerId(marker.id),
          position: marker.point.latLng,
          infoWindow: InfoWindow(title: marker.label),
          onTap: () => widget.onMarkerTap?.call(marker.id),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            selected ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueRed,
          ),
          zIndexInt: selected ? 2 : 1,
        );
      }),
    };

    final routePoints = widget.routePoints.isNotEmpty
        ? widget.routePoints.map((point) => point.latLng).toList()
        : <LatLng>[
            if (widget.driver != null) widget.driver!.latLng,
            widget.pickup.latLng,
            if (widget.destination != null) widget.destination!.latLng,
          ];

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.pickup.latLng,
        zoom: 14,
      ),
      myLocationButtonEnabled: false,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      padding: widget.padding,
      // Gesture flags: disabled for embedded preview maps so the parent
      // scroll view gets touch/scroll events instead of the map.
      scrollGesturesEnabled: widget.gesturesEnabled,
      zoomGesturesEnabled: widget.gesturesEnabled,
      rotateGesturesEnabled: widget.gesturesEnabled,
      tiltGesturesEnabled: widget.gesturesEnabled,
      markers: markers,
      polylines: {
        if (widget.showRoute && routePoints.length > 1)
          Polyline(
            polylineId: const PolylineId('demo-route'),
            points: routePoints,
            color: _accentBlue,
            width: 5,
          ),
      },
      onMapCreated: (controller) {
        if (!_controller.isCompleted) {
          _controller.complete(controller);
        }
        _moveCameraToVisibleMarkers();
      },
      onTap: (latLng) => widget.onMapTap?.call(
        DemoMapPoint(latLng.latitude, latLng.longitude),
      ),
    );
  }

  Future<void> _moveCameraToVisibleMarkers() async {
    if (!_canUseGoogleMap || !_controller.isCompleted) {
      return;
    }
    final controller = await _controller.future;
    final points = <DemoMapPoint>[
      widget.pickup,
      if (widget.destination != null) widget.destination!,
      if (widget.driver != null) widget.driver!,
      ...widget.routePoints,
      ...widget.offerMarkers.map((marker) => marker.point),
    ];
    if (points.length < 2) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: widget.pickup.latLng, zoom: 15),
        ),
      );
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    try {
      if ((maxLat - minLat).abs() < 0.0001 &&
          (maxLng - minLng).abs() < 0.0001) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: widget.pickup.latLng, zoom: 15),
          ),
        );
        return;
      }
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          72,
        ),
      );
    } catch (_) {
      // Keep the active map visible even if a web camera update races layout.
    }
  }

  String get _fallbackReason {
    if (!kUseGoogleMaps) {
      return 'Map not configured';
    }
    if (_isLoadingGoogleMap) {
      return 'Loading…';
    }
    return _webGmapsReason;
  }

  Widget _fallbackMap({required String label, required String reason}) {
    return FakeMapBackground(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.showRoute)
            CustomPaint(
              painter: _FallbackRoutePainter(
                includeDriver: widget.driver != null,
                includeDestination: widget.destination != null,
              ),
            ),
          const _FallbackMarker(
            alignment: Alignment(-0.14, 0.08),
            icon: Icons.trip_origin,
            color: _accentBlue,
            label: 'Pickup',
          ),
          if (widget.destination != null)
            const _FallbackMarker(
              alignment: Alignment(0.56, -0.22),
              icon: Icons.place,
              color: Color(0xFFD32F2F),
              label: 'Destination',
            ),
          if (widget.driver != null)
            const _FallbackMarker(
              alignment: Alignment(-0.58, 0.38),
              icon: Icons.navigation,
              color: Color(0xFF00796B),
              label: 'Driver',
            ),
          ...List.generate(widget.offerMarkers.length, (index) {
            final marker = widget.offerMarkers[index];
            final selected = widget.selectedMarkerId == marker.id;
            return _FallbackOfferMarker(
              marker: marker,
              selected: selected,
              alignment: _fallbackOfferAlignment(index),
              onTap: () => widget.onMarkerTap?.call(marker.id),
            );
          }),
          _MapStatusLabel(
            label: label,
            reason: reason,
            icon: Icons.layers_outlined,
            alignment: Alignment.bottomRight,
          ),
        ],
      ),
    );
  }

  Widget _mapWithStatusLabel({
    required Widget child,
    required String label,
    required IconData icon,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        _MapStatusLabel(
          label: label,
          icon: icon,
          alignment: Alignment.bottomRight,
        ),
      ],
    );
  }

  Alignment _fallbackOfferAlignment(int index) {
    const alignments = [
      Alignment(0.34, -0.42),
      Alignment(0.72, -0.08),
      Alignment(0.42, 0.34),
      Alignment(-0.02, -0.34),
      Alignment(0.76, 0.42),
      Alignment(-0.36, -0.08),
    ];
    return alignments[index % alignments.length];
  }
}

/// Small badge shown on embedded (non-interactive) map previews.
/// Communicates to the user that the map is view-only in this context.
class _MapPreviewBadge extends StatelessWidget {
  const _MapPreviewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Map preview',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MapStatusLabel extends StatelessWidget {
  const _MapStatusLabel({
    required this.label,
    this.reason,
    required this.icon,
    required this.alignment,
  });

  final String label;
  final String? reason;
  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: _accentBlue),
              const SizedBox(width: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (reason != null && reason!.isNotEmpty)
                    Text(
                      reason!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FakeMapBackground extends StatelessWidget {
  const FakeMapBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _FakeMapPainter(), size: Size.infinite),
        child,
      ],
    );
  }
}

class _FakeMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_mapBgTop, _mapBgBottom],
        ).createShader(rect),
    );

    final parkPaint = Paint()..color = const Color(0xFFCFE6D4);
    final waterPaint = Paint()..color = const Color(0xFFB7D7EC);
    final buildingPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final minorRoad = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final majorRoad = Paint()
      ..color = const Color(0xFFF8D86A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final roadEdge = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.04,
          size.height * 0.12,
          size.width * 0.32,
          120,
        ),
        const Radius.circular(18),
      ),
      parkPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.62,
        size.height * 0.1,
        size.width * 0.34,
        150,
      ),
      waterPaint,
    );

    for (final rect in [
      Rect.fromLTWH(size.width * 0.12, size.height * 0.36, 86, 58),
      Rect.fromLTWH(size.width * 0.58, size.height * 0.38, 96, 70),
      Rect.fromLTWH(size.width * 0.18, size.height * 0.68, 116, 72),
      Rect.fromLTWH(size.width * 0.68, size.height * 0.66, 74, 94),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        buildingPaint,
      );
    }

    final mainPath = Path()
      ..moveTo(-20, size.height * 0.72)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.56,
        size.width * 0.42,
        size.height * 0.58,
        size.width * 0.54,
        size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.67,
        size.height * 0.25,
        size.width * 0.84,
        size.height * 0.31,
        size.width + 20,
        size.height * 0.2,
      );
    canvas.drawPath(mainPath, roadEdge);
    canvas.drawPath(mainPath, majorRoad);

    final sideRoads = [
      Path()
        ..moveTo(size.width * 0.18, -10)
        ..lineTo(size.width * 0.28, size.height * 0.34)
        ..lineTo(size.width * 0.35, size.height + 10),
      Path()
        ..moveTo(size.width * 0.76, -10)
        ..lineTo(size.width * 0.66, size.height * 0.5)
        ..lineTo(size.width * 0.82, size.height + 10),
      Path()
        ..moveTo(-10, size.height * 0.48)
        ..lineTo(size.width * 0.42, size.height * 0.5)
        ..lineTo(size.width + 10, size.height * 0.58),
    ];
    for (final path in sideRoads) {
      canvas.drawPath(path, minorRoad);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FallbackRoutePainter extends CustomPainter {
  const _FallbackRoutePainter({
    required this.includeDriver,
    required this.includeDestination,
  });

  final bool includeDriver;
  final bool includeDestination;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _accentYellow.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final path = Path();
    if (includeDriver) {
      path
        ..moveTo(size.width * 0.2, size.height * 0.7)
        ..quadraticBezierTo(
          size.width * 0.36,
          size.height * 0.62,
          size.width * 0.43,
          size.height * 0.54,
        );
    } else {
      path.moveTo(size.width * 0.43, size.height * 0.54);
    }
    if (includeDestination) {
      path.cubicTo(
        size.width * 0.52,
        size.height * 0.38,
        size.width * 0.6,
        size.height * 0.28,
        size.width * 0.72,
        size.height * 0.32,
      );
    }
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _FallbackRoutePainter oldDelegate) {
    return includeDriver != oldDelegate.includeDriver ||
        includeDestination != oldDelegate.includeDestination;
  }
}

class _FallbackMarker extends StatelessWidget {
  const _FallbackMarker({
    required this.alignment,
    required this.icon,
    required this.color,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackOfferMarker extends StatelessWidget {
  const _FallbackOfferMarker({
    required this.marker,
    required this.selected,
    required this.alignment,
    required this.onTap,
  });

  final DemoMapMarker marker;
  final bool selected;
  final Alignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? _accentYellow : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.black87 : const Color(0xFFD32F2F),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                marker.icon,
                size: 17,
                color: selected ? Colors.black87 : const Color(0xFFD32F2F),
              ),
              const SizedBox(width: 5),
              Text(
                marker.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
