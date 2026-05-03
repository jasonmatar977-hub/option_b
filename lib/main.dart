import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const OptionBApp());
}

// --- Theme & constants ---

const Color kAccentYellow = Color(0xFFFFD000);
const Color kAccentBlue = Color(0xFF1565C0);
const Color kMapBgTop = Color(0xFF1E3A5F);
const Color kMapBgBottom = Color(0xFF2D5A87);

enum ServiceType { ride, moto, courier }

String serviceLabel(ServiceType s) {
  switch (s) {
    case ServiceType.ride:
      return 'Ride';
    case ServiceType.moto:
      return 'Moto';
    case ServiceType.courier:
      return 'Courier';
  }
}

class PriceBand {
  const PriceBand({
    required this.minimum,
    required this.maximum,
    required this.fair,
    required this.fast,
  });
  final int minimum;
  final int maximum;
  final int fair;
  final int fast;
}

PriceBand bandFor(ServiceType s) {
  switch (s) {
    case ServiceType.ride:
      return const PriceBand(minimum: 12, maximum: 38, fair: 19, fast: 29);
    case ServiceType.moto:
      return const PriceBand(minimum: 8, maximum: 24, fair: 13, fast: 19);
    case ServiceType.courier:
      return const PriceBand(minimum: 15, maximum: 48, fair: 24, fast: 36);
  }
}

class DriverInfo {
  const DriverInfo({
    required this.name,
    required this.rating,
    required this.vehicle,
    required this.distanceKm,
    required this.etaMin,
  });
  final String name;
  final double rating;
  final String vehicle;
  final double distanceKm;
  final int etaMin;
}

class OfferPayload {
  OfferPayload({
    required this.id,
    required this.service,
    required this.pickup,
    required this.destination,
    required this.offerAmount,
  });
  final String id;
  final ServiceType service;
  final String pickup;
  final String destination;
  final int offerAmount;
}

// --- Reusable widgets ---

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
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [kMapBgTop, kMapBgBottom],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 48.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final block = Paint()..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, size.height * 0.22, size.width * 0.35, 90),
        const Radius.circular(8),
      ),
      block,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.55, size.height * 0.45, size.width * 0.28, 120),
        const Radius.circular(8),
      ),
      block,
    );

    final pathPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.65)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.5,
        size.width * 0.72,
        size.height * 0.38,
      );
    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CurrentLocationMarker extends StatelessWidget {
  const CurrentLocationMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: kAccentBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: kAccentBlue.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class PrimaryCtaButton extends StatelessWidget {
  const PrimaryCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kAccentYellow,
          foregroundColor: Colors.black87,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

// --- App root ---

class OptionBApp extends StatelessWidget {
  const OptionBApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Option B',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccentBlue,
          brightness: Brightness.light,
          primary: kAccentBlue,
        ),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const MainMapScreen(),
    );
  }
}

// --- 1. Main map-first customer screen ---

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({super.key});

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {
  ServiceType _service = ServiceType.ride;
  final TextEditingController _destinationCtrl = TextEditingController();
  late int _offerAmount;

  @override
  void initState() {
    super.initState();
    _syncOfferToFair();
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    super.dispose();
  }

  void _syncOfferToFair() {
    _offerAmount = bandFor(_service).fair;
  }

  String get _destinationHint {
    switch (_service) {
      case ServiceType.courier:
        return 'Where should we deliver?';
      case ServiceType.ride:
      case ServiceType.moto:
        return 'Where to?';
    }
  }

  void _sendOffer() {
    final dest = _destinationCtrl.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination')),
      );
      return;
    }
    final id = 'OPT-B-${1000 + math.Random().nextInt(9000)}';
    final payload = OfferPayload(
      id: id,
      service: _service,
      pickup: 'Current Location',
      destination: dest,
      offerAmount: _offerAmount,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OfferMatchingScreen(offer: payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final band = bandFor(_service);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: FakeMapBackground(
        child: Stack(
          children: [
            const CurrentLocationMarker(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DriverOfferScreen(
                              previewOffer: OfferPayload(
                                id: 'OPT-B-8891',
                                service: ServiceType.ride,
                                pickup: 'Current Location',
                                destination: 'Central Station',
                                offerAmount: 19,
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.local_taxi_outlined),
                      tooltip: 'Driver view',
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Option B',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.52,
              minChildSize: 0.38,
              maxChildSize: 0.88,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 16,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SectionLabel('Service'),
                      SegmentedButton<ServiceType>(
                        segments: const [
                          ButtonSegment(value: ServiceType.ride, label: Text('Ride')),
                          ButtonSegment(value: ServiceType.moto, label: Text('Moto')),
                          ButtonSegment(value: ServiceType.courier, label: Text('Courier')),
                        ],
                        selected: {_service},
                        onSelectionChanged: (set) {
                          setState(() {
                            _service = set.first;
                            _syncOfferToFair();
                          });
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          padding: WidgetStateProperty.all(
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Pickup'),
                      TextFormField(
                        initialValue: 'Current Location',
                        readOnly: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.my_location, color: kAccentBlue),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SectionLabel('Destination'),
                      TextField(
                        controller: _destinationCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: _destinationHint,
                          prefixIcon: const Icon(Icons.place_outlined, color: kAccentBlue),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Your offer'),
                      Text(
                        'Suggested min \$${band.minimum} · max \$${band.maximum}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(_offerAmount),
                              initialValue: '\$$_offerAmount',
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Your offer',
                                prefixIcon: Icon(Icons.attach_money, color: kAccentBlue),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PriceChip(
                            label: 'Minimum',
                            value: band.minimum,
                            selected: _offerAmount == band.minimum,
                            onTap: () => setState(() => _offerAmount = band.minimum),
                          ),
                          _PriceChip(
                            label: 'Fair',
                            value: band.fair,
                            selected: _offerAmount == band.fair,
                            onTap: () => setState(() => _offerAmount = band.fair),
                          ),
                          _PriceChip(
                            label: 'Fast',
                            value: band.fast,
                            selected: _offerAmount == band.fast,
                            onTap: () => setState(() => _offerAmount = band.fast),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PrimaryCtaButton(label: 'Send Offer', onPressed: _sendOffer),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('$label · \$$value'),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: kAccentYellow.withValues(alpha: 0.5),
      checkmarkColor: Colors.black87,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected ? Colors.black87 : Colors.grey.shade800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }
}

// --- 2. Offer matching ---

List<DriverInfo> _demoDrivers() {
  return const [
    DriverInfo(name: 'Alex M.', rating: 4.9, vehicle: 'Toyota Prius', distanceKm: 0.8, etaMin: 3),
    DriverInfo(name: 'Jordan K.', rating: 4.8, vehicle: 'Honda Civic', distanceKm: 1.2, etaMin: 5),
    DriverInfo(name: 'Sam R.', rating: 5.0, vehicle: 'Nissan Leaf', distanceKm: 1.5, etaMin: 6),
  ];
}

class OfferMatchingScreen extends StatelessWidget {
  const OfferMatchingScreen({super.key, required this.offer});

  final OfferPayload offer;

  @override
  Widget build(BuildContext context) {
    final drivers = _demoDrivers();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finding drivers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              offer.id,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              serviceLabel(offer.service),
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 28),
            _kv('Pickup', offer.pickup),
            const SizedBox(height: 8),
            _kv('Destination', offer.destination),
            const SizedBox(height: 8),
            _kv('Your offer', '\$${offer.offerAmount}'),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAccentBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.near_me, color: kAccentBlue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Offer sent to nearby drivers',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nearby drivers',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            ...drivers.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DriverCard(driver: d),
                )),
            const SizedBox(height: 8),
            PrimaryCtaButton(
              label: 'Simulate Driver Accepts',
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => TrackingScreen(offer: offer, driver: drivers.first),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(k, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ),
        Expanded(
          child: Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final DriverInfo driver;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: kAccentYellow.withValues(alpha: 0.6),
              child: Text(
                driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 18, color: Color(0xFFFFA000)),
                      Text(' ${driver.rating}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(' · ${driver.vehicle}', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${driver.distanceKm} km away · ETA ${driver.etaMin} min',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. Tracking ---

const List<String> kTrackingSteps = [
  'Offer sent',
  'Driver accepted',
  'Driver on the way',
  'Arrived at pickup',
  'In progress',
  'Completed',
];

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.offer, required this.driver});

  final OfferPayload offer;
  final DriverInfo driver;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  /// Index of the current in-progress step (0–5). Earlier steps are completed.
  int _stepIndex = 2;

  void _advance() {
    if (_stepIndex >= kTrackingSteps.length - 1) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Trip complete'),
          content: const Text('Thanks for trying Option B (demo).'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _stepIndex++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live trip'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DriverCard(driver: widget.driver),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: FakeMapBackground(
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: const Size(double.infinity, 180),
                        painter: _RoutePreviewPainter(),
                      ),
                      const Align(
                        alignment: Alignment(-0.65, 0.35),
                        child: Icon(Icons.trip_origin, color: kAccentBlue, size: 28),
                      ),
                      const Align(
                        alignment: Alignment(0.55, -0.25),
                        child: Icon(Icons.place, color: Color(0xFFD32F2F), size: 32),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Status',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 12),
            ...List.generate(kTrackingSteps.length, (i) {
              final completed = i < _stepIndex;
              final active = i == _stepIndex;
              final pending = i > _stepIndex;
              final IconData icon;
              final Color iconColor;
              if (completed) {
                icon = Icons.check_circle;
                iconColor = kAccentBlue;
              } else if (active) {
                icon = Icons.radio_button_checked;
                iconColor = const Color(0xFFCC9900);
              } else {
                icon = Icons.radio_button_off;
                iconColor = Colors.grey.shade400;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: iconColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        kTrackingSteps[i],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: pending ? Colors.grey.shade500 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            PrimaryCtaButton(
              label: _stepIndex >= kTrackingSteps.length - 1
                  ? 'Complete flow'
                  : 'Simulate next step',
              onPressed: _advance,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Call (demo)')),
                      );
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: kAccentBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message (demo)')),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: kAccentBlue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = kAccentYellow.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.72)
      ..cubicTo(
        size.width * 0.4,
        size.height * 0.55,
        size.width * 0.5,
        size.height * 0.35,
        size.width * 0.68,
        size.height * 0.28,
      );
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 4. Driver offer view ---

class DriverOfferScreen extends StatefulWidget {
  const DriverOfferScreen({super.key, required this.previewOffer});

  final OfferPayload previewOffer;

  @override
  State<DriverOfferScreen> createState() => _DriverOfferScreenState();
}

class _DriverOfferScreenState extends State<DriverOfferScreen> {
  bool _accepted = false;
  bool _rejected = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.previewOffer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver — incoming'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_rejected)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Offer rejected (demo).',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                ),
              ),
            if (!_rejected)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.id,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        serviceLabel(o.service),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Divider(height: 22),
                      _driverKeyValue('Pickup', o.pickup),
                      _driverKeyValue('Drop-off', o.destination),
                      _driverKeyValue('Customer offer', '\$${o.offerAmount}'),
                    ],
                  ),
                ),
              ),
            if (!_accepted && !_rejected) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => setState(() => _rejected = true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: () => setState(() => _accepted = true),
                        style: FilledButton.styleFrom(
                          backgroundColor: kAccentBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_accepted) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kAccentYellow.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Offer accepted',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Active job',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 8),
              Text('${o.pickup} → ${o.destination}', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 6),
              Text('Earn \$${o.offerAmount} · ${serviceLabel(o.service)}', style: TextStyle(color: Colors.grey.shade700)),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _driverKeyValue(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(k, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
