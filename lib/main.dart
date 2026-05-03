import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/directions_service.dart';
import 'services/google_places_service.dart';
import 'services/location_service.dart';
import 'widgets/app_map.dart';

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

const Color kAccentYellow = Color(0xFFFFD000);
const Color kAccentBlue = Color(0xFF1565C0);
const String kCurrentPickup = 'Current Location';
const DemoMapPoint kDemoPickupPoint = DemoMapPoint(33.8938, 35.5018);
const DemoMapPoint kDemoDestinationPoint = DemoMapPoint(33.9006, 35.5144);

enum ServiceType { ride, moto, courier }

enum DemoRole { customer, driver }

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

IconData serviceIcon(ServiceType s) {
  switch (s) {
    case ServiceType.ride:
      return Icons.directions_car_filled_outlined;
    case ServiceType.moto:
      return Icons.two_wheeler_outlined;
    case ServiceType.courier:
      return Icons.local_shipping_outlined;
  }
}

class PriceBand {
  const PriceBand({
    required this.minimum,
    required this.maximum,
    required this.recommended,
    required this.fast,
  });

  final int minimum;
  final int maximum;
  final int recommended;
  final int fast;
}

PriceBand bandFor(ServiceType s) {
  switch (s) {
    case ServiceType.ride:
      return const PriceBand(
        minimum: 12,
        maximum: 38,
        recommended: 19,
        fast: 29,
      );
    case ServiceType.moto:
      return const PriceBand(
        minimum: 8,
        maximum: 24,
        recommended: 13,
        fast: 19,
      );
    case ServiceType.courier:
      return const PriceBand(
        minimum: 15,
        maximum: 48,
        recommended: 24,
        fast: 36,
      );
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
    this.pickupPoint,
    this.destinationPoint,
    this.routePoints = const [],
    this.distanceText,
    this.durationText,
    this.manualDestination = false,
  });

  final String id;
  final ServiceType service;
  final String pickup;
  final String destination;
  final int offerAmount;
  final DemoMapPoint? pickupPoint;
  final DemoMapPoint? destinationPoint;
  final List<DemoMapPoint> routePoints;
  final String? distanceText;
  final String? durationText;
  final bool manualDestination;
}

class CompletedOffer {
  const CompletedOffer({
    required this.offer,
    required this.driver,
    required this.status,
  });

  final OfferPayload offer;
  final DriverInfo driver;
  final String status;
}

class BookAgainPayload {
  const BookAgainPayload({
    required this.service,
    required this.destination,
    required this.offerAmount,
  });

  final ServiceType service;
  final String destination;
  final int offerAmount;
}

final List<CompletedOffer> demoHistory = <CompletedOffer>[];

class DemoDriverAvailability {
  bool isOnline = false;
  DemoMapPoint location = const DemoMapPoint(33.8898, 35.4948);
  String locationLabel = 'Demo driver location';
}

final DemoDriverAvailability demoDriverAvailability = DemoDriverAvailability();

List<DriverInfo> demoDrivers(ServiceType service) {
  switch (service) {
    case ServiceType.ride:
      return const [
        DriverInfo(
          name: 'Alex M.',
          rating: 4.9,
          vehicle: 'Toyota Prius',
          distanceKm: 0.8,
          etaMin: 3,
        ),
        DriverInfo(
          name: 'Jordan K.',
          rating: 4.8,
          vehicle: 'Honda Civic',
          distanceKm: 1.2,
          etaMin: 5,
        ),
        DriverInfo(
          name: 'Sam R.',
          rating: 5.0,
          vehicle: 'Nissan Leaf',
          distanceKm: 1.5,
          etaMin: 6,
        ),
      ];
    case ServiceType.moto:
      return const [
        DriverInfo(
          name: 'Maya T.',
          rating: 4.9,
          vehicle: 'Yamaha NMAX',
          distanceKm: 0.5,
          etaMin: 2,
        ),
        DriverInfo(
          name: 'Omar H.',
          rating: 4.7,
          vehicle: 'Honda PCX',
          distanceKm: 1.1,
          etaMin: 4,
        ),
        DriverInfo(
          name: 'Rami S.',
          rating: 4.8,
          vehicle: 'Suzuki Burgman',
          distanceKm: 1.7,
          etaMin: 6,
        ),
      ];
    case ServiceType.courier:
      return const [
        DriverInfo(
          name: 'Nour A.',
          rating: 4.9,
          vehicle: 'Courier van',
          distanceKm: 0.9,
          etaMin: 4,
        ),
        DriverInfo(
          name: 'Lina K.',
          rating: 4.8,
          vehicle: 'Box moto',
          distanceKm: 1.3,
          etaMin: 6,
        ),
        DriverInfo(
          name: 'Ziad F.',
          rating: 4.7,
          vehicle: 'Compact van',
          distanceKm: 2.0,
          etaMin: 8,
        ),
      ];
  }
}

List<DriverInfo> onlineDriversFor(ServiceType service) {
  if (!demoDriverAvailability.isOnline) {
    return const [];
  }
  return [demoDrivers(service).first];
}

class OptionBApp extends StatefulWidget {
  const OptionBApp({super.key});

  @override
  State<OptionBApp> createState() => _OptionBAppState();
}

class _OptionBAppState extends State<OptionBApp> {
  DemoRole? _selectedRole;
  String? _phoneNumber;
  bool _isVerified = false;

  void _selectRole(DemoRole role) {
    setState(() {
      _selectedRole = role;
      _phoneNumber = null;
      _isVerified = false;
    });
  }

  void _sendCode(String phone) {
    setState(() => _phoneNumber = phone);
  }

  void _verify() {
    setState(() => _isVerified = true);
  }

  void _signOut() {
    setState(() {
      _selectedRole = null;
      _phoneNumber = null;
      _isVerified = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = _selectedRole;
    final phone = _phoneNumber;
    Widget home;
    if (role == null) {
      home = RoleSelectionScreen(onRoleSelected: _selectRole);
    } else if (phone == null) {
      home = PhoneLoginScreen(role: role, onCodeSent: _sendCode);
    } else if (!_isVerified) {
      home = OtpVerificationScreen(
        role: role,
        phoneNumber: phone,
        onVerified: _verify,
      );
    } else if (role == DemoRole.customer) {
      home = MainMapScreen(userPhone: phone, onSignOut: _signOut);
    } else {
      home = DriverHomeScreen(userPhone: phone, onSignOut: _signOut);
    }

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
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      home: home,
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key, required this.onRoleSelected});

  final ValueChanged<DemoRole> onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'Option B',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to use the app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              _RoleCard(
                icon: Icons.near_me_outlined,
                title: 'I need a service',
                subtitle: 'Request a ride, moto, or courier',
                onTap: () => onRoleSelected(DemoRole.customer),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                icon: Icons.work_outline,
                title: 'I want to work',
                subtitle: 'Go online and accept nearby offers',
                onTap: () => onRoleSelected(DemoRole.driver),
              ),
              const SizedBox(height: 20),
              Text(
                'Live simulation - no real SMS or backend',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: kAccentBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: kAccentBlue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({
    super.key,
    required this.role,
    required this.onCodeSent,
  });

  final DemoRole role;
  final ValueChanged<String> onCodeSent;

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _continue() {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Phone number is required');
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Demo code sent: 1234')));
    widget.onCodeSent(phone);
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = widget.role == DemoRole.driver;
    return Scaffold(
      appBar: AppBar(title: const Text('Phone login')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              isDriver ? Icons.work_outline : Icons.near_me_outlined,
              color: kAccentBlue,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              isDriver ? 'Driver access' : 'Customer access',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your phone number to continue. Demo verification code: 1234',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone number',
                errorText: _error,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            const SizedBox(height: 20),
            PrimaryCtaButton(label: 'Continue', onPressed: _continue),
          ],
        ),
      ),
    );
  }
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.role,
    required this.phoneNumber,
    required this.onVerified,
  });

  final DemoRole role;
  final String phoneNumber;
  final VoidCallback onVerified;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _codeCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _verify() {
    if (_codeCtrl.text.trim() != '1234') {
      setState(() => _error = 'That code is not correct. Use 1234 for demo.');
      return;
    }
    widget.onVerified();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify phone')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Enter verification code',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Demo code sent to ${widget.phoneNumber}: 1234',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Code',
                errorText: _error,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
            const SizedBox(height: 20),
            PrimaryCtaButton(label: 'Verify', onPressed: _verify),
          ],
        ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

class MainMapScreen extends StatefulWidget {
  const MainMapScreen({
    super.key,
    required this.userPhone,
    required this.onSignOut,
  });

  final String userPhone;
  final VoidCallback onSignOut;

  @override
  State<MainMapScreen> createState() => _MainMapScreenState();
}

class _MainMapScreenState extends State<MainMapScreen> {
  final GooglePlacesService _placesService = const GooglePlacesService();
  final DirectionsService _directionsService = const DirectionsService();
  ServiceType _service = ServiceType.ride;
  final TextEditingController _destinationCtrl = TextEditingController();
  final TextEditingController _offerCtrl = TextEditingController();
  Timer? _destinationDebounce;
  String? _destinationError;
  String? _offerError;
  String _pickupLabel = kCurrentPickup;
  DemoMapPoint _pickupPoint = kDemoPickupPoint;
  DemoMapPoint? _selectedDestinationPoint;
  String? _selectedDestinationText;
  List<PlaceSuggestion> _suggestions = const [];
  bool _loadingSuggestions = false;
  String? _placesMessage;
  RouteEstimate? _routeEstimate;
  bool _loadingEstimate = false;
  int _mapCameraKey = 0;
  bool _locating = false;
  bool _showLowOfferWarning = false;

  @override
  void initState() {
    super.initState();
    _setOffer(bandFor(_service).recommended);
  }

  @override
  void dispose() {
    _destinationDebounce?.cancel();
    _destinationCtrl.dispose();
    _offerCtrl.dispose();
    super.dispose();
  }

  DemoMapPoint? get _destinationPoint {
    if (_selectedDestinationPoint != null &&
        _destinationCtrl.text.trim() == _selectedDestinationText) {
      return _selectedDestinationPoint;
    }
    return null;
  }

  bool get _destinationWasManual {
    final typed = _destinationCtrl.text.trim();
    return typed.isNotEmpty && typed != _selectedDestinationText;
  }

  PriceBand get _activePriceBand {
    final base = bandFor(_service);
    final estimate = _routeEstimate;
    if (estimate == null) {
      return base;
    }
    final adjustment = switch (_service) {
      ServiceType.ride => 2.0,
      ServiceType.moto => 1.4,
      ServiceType.courier => 2.4,
    };
    final minimum = math.max(
      base.minimum,
      (5 + estimate.distanceKm * adjustment).round(),
    );
    final recommended = math.max(minimum + 2, (minimum * 1.35).round());
    final fast = math.max(recommended + 4, (recommended * 1.28).round());
    return PriceBand(
      minimum: minimum,
      maximum: math.max(base.maximum, fast + 10),
      recommended: recommended,
      fast: fast,
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final result = await LocationService.getCurrentLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      if (result.point != null) {
        _pickupPoint = result.point!;
        _pickupLabel = 'GPS current location';
        _mapCameraKey++;
      }
    });
    if (result.point != null && _destinationPoint != null) {
      await _updateEstimate();
      if (!mounted) {
        return;
      }
    }
    final message =
        result.message ??
        (result.status == DemoLocationStatus.allowed
            ? 'Current location detected'
            : null);
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String get _destinationHint {
    if (_service == ServiceType.courier) {
      return 'Delivery drop-off';
    }
    return 'Where to?';
  }

  int? get _offerAmount => int.tryParse(_offerCtrl.text.trim());

  void _setOffer(int value) {
    final band = _activePriceBand;
    final clamped = value.clamp(band.minimum, band.maximum).toInt();
    _offerCtrl.text = clamped.toString();
    _offerCtrl.selection = TextSelection.collapsed(
      offset: _offerCtrl.text.length,
    );
    _offerError = null;
    _showLowOfferWarning = clamped < band.minimum;
  }

  void _onDestinationChanged(String value) {
    if (_destinationError != null) {
      _destinationError = null;
    }
    _selectedDestinationPoint = null;
    _selectedDestinationText = null;
    _routeEstimate = null;
    _placesMessage = null;
    _destinationDebounce?.cancel();

    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _loadingSuggestions = false;
      });
      return;
    }

    setState(() => _loadingSuggestions = true);
    _destinationDebounce = Timer(const Duration(milliseconds: 400), () async {
      final localResults = _placesService.localSuggestions(query);
      try {
        final googleResults = _placesService.isConfigured
            ? await _placesService.autocomplete(query)
            : const <PlaceSuggestion>[];
        if (!mounted || _destinationCtrl.text.trim() != query) {
          return;
        }
        final results = <PlaceSuggestion>[
          ...localResults,
          ...googleResults.where(
            (google) => localResults.every(
              (local) =>
                  local.mainText.toLowerCase() != google.mainText.toLowerCase(),
            ),
          ),
        ];
        setState(() {
          _suggestions = results.take(5).toList();
          _loadingSuggestions = false;
          _placesMessage = results.isEmpty
              ? 'No matching places found.'
              : googleResults.isEmpty && localResults.isNotEmpty
              ? 'Showing local suggestions.'
              : null;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _suggestions = localResults.take(5).toList();
          _loadingSuggestions = false;
          _placesMessage = localResults.isEmpty
              ? 'Autocomplete unavailable. You can type manually.'
              : 'Places unavailable. Showing local suggestions.';
        });
      }
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loadingSuggestions = true;
      _suggestions = const [];
      _placesMessage = null;
    });
    if (suggestion.localPoint != null) {
      setState(() {
        _destinationCtrl.text = suggestion.mainText;
        _selectedDestinationText = suggestion.mainText;
        _selectedDestinationPoint = suggestion.localPoint;
        _loadingSuggestions = false;
        _mapCameraKey++;
      });
      await _updateEstimate();
      return;
    }
    try {
      final details = await _placesService.details(suggestion.placeId);
      if (!mounted) {
        return;
      }
      setState(() {
        _destinationCtrl.text = details.name;
        _selectedDestinationText = details.name;
        _selectedDestinationPoint = details.point;
        _loadingSuggestions = false;
        _mapCameraKey++;
      });
      await _updateEstimate();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _destinationCtrl.text = suggestion.mainText;
        _selectedDestinationText = suggestion.mainText;
        _selectedDestinationPoint = null;
        _loadingSuggestions = false;
        _placesMessage =
            'Place details unavailable. You can continue manually.';
      });
    }
  }

  Future<void> _updateEstimate({bool useFallbackOnly = false}) async {
    final destination = _destinationPoint;
    if (destination == null) {
      return;
    }

    setState(() => _loadingEstimate = true);
    RouteEstimate estimate;
    try {
      estimate = useFallbackOnly
          ? _directionsService.fallback(
              pickup: _pickupPoint,
              destination: destination,
            )
          : await _directionsService.route(
              pickup: _pickupPoint,
              destination: destination,
            );
    } catch (_) {
      estimate = _directionsService.fallback(
        pickup: _pickupPoint,
        destination: destination,
      );
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _routeEstimate = estimate;
      _loadingEstimate = false;
      _mapCameraKey++;
      final band = _activePriceBand;
      if (_offerAmount == null ||
          _offerAmount == bandFor(_service).recommended) {
        _setOffer(band.recommended);
      }
    });
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('History'),
                subtitle: const Text('Completed demo offers'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final booked = await Navigator.of(context)
                      .push<BookAgainPayload>(
                        MaterialPageRoute<BookAgainPayload>(
                          builder: (_) => const HistoryScreen(),
                        ),
                      );
                  if (booked != null) {
                    setState(() {
                      _service = booked.service;
                      _destinationCtrl.text = booked.destination;
                      _setOffer(booked.offerAmount);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_taxi_outlined),
                title: const Text('Driver mode'),
                subtitle: const Text('Go online in the local demo'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DriverHomeScreen(
                        userPhone: widget.userPhone,
                        onSignOut: widget.onSignOut,
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() => _mapCameraKey++);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                subtitle: Text(widget.userPhone),
                onTap: () {
                  Navigator.of(ctx).pop();
                  widget.onSignOut();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendOffer() async {
    final dest = _destinationCtrl.text.trim();
    final amount = _offerAmount;
    final band = _activePriceBand;
    var payloadDestinationPoint = _destinationPoint;
    var payloadRouteEstimate = _routeEstimate;

    setState(() {
      _destinationError = dest.isEmpty ? 'Destination is required' : null;
      _offerError = amount == null ? 'Offer amount is required' : null;
      _showLowOfferWarning = amount != null && amount < band.minimum;
    });

    if (_destinationError != null || _offerError != null || amount == null) {
      return;
    }

    if (_destinationWasManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a suggestion for accurate ETA, or continue manually.',
          ),
        ),
      );
      payloadDestinationPoint ??= kDemoDestinationPoint;
      payloadRouteEstimate ??= _directionsService.fallback(
        pickup: _pickupPoint,
        destination: payloadDestinationPoint,
      );
      if (!mounted) {
        return;
      }
    }

    if (amount < band.minimum) {
      final keepGoing = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Low offer'),
          content: Text(
            'The suggested minimum for ${serviceLabel(_service).toLowerCase()} is \$${band.minimum}. '
            'Drivers may ignore lower offers. Send it anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Edit offer'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Send anyway'),
            ),
          ],
        ),
      );
      if (keepGoing != true) {
        return;
      }
    }

    final payload = OfferPayload(
      id: 'OPT-B-${1000 + math.Random().nextInt(9000)}',
      service: _service,
      pickup: _pickupLabel,
      destination: dest,
      offerAmount: amount,
      pickupPoint: _pickupPoint,
      destinationPoint: payloadDestinationPoint,
      routePoints: payloadRouteEstimate?.routePoints ?? const [],
      distanceText: payloadRouteEstimate?.distanceText,
      durationText: payloadRouteEstimate?.durationText,
      manualDestination: _destinationWasManual,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OfferMatchingScreen(offer: payload),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final band = _activePriceBand;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              pickup: _pickupPoint,
              destination: _destinationPoint,
              driver: demoDriverAvailability.isOnline
                  ? demoDriverAvailability.location
                  : null,
              routePoints: _routeEstimate?.routePoints ?? const [],
              cameraUpdateKey: _mapCameraKey,
              showRoute: _destinationPoint != null,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                    ),
                    onPressed: _openMenu,
                    icon: const Icon(Icons.menu),
                    tooltip: 'Menu',
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _locating ? null : _useCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_locating)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(
                              Icons.my_location,
                              size: 18,
                              color: kAccentBlue,
                            ),
                          const SizedBox(width: 8),
                          Text(
                            _pickupLabel == kCurrentPickup
                                ? 'Current location'
                                : 'GPS location',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.58,
            minChildSize: 0.42,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
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
                          width: 42,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Make an offer',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a service, set your price, and nearby drivers can accept.',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SectionLabel('Service'),
                      Row(
                        children: ServiceType.values
                            .map(
                              (s) => Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    right: s == ServiceType.courier ? 0 : 8,
                                  ),
                                  child: _ServiceOption(
                                    service: s,
                                    selected: _service == s,
                                    onTap: () {
                                      setState(() {
                                        _service = s;
                                        _setOffer(_activePriceBand.recommended);
                                      });
                                    },
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      const SectionLabel('Pickup'),
                      TextFormField(
                        key: ValueKey(_pickupLabel),
                        initialValue: _pickupLabel,
                        readOnly: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.my_location,
                            color: kAccentBlue,
                          ),
                          suffixIcon: IconButton(
                            onPressed: _locating ? null : _useCurrentLocation,
                            icon: const Icon(Icons.gps_fixed),
                            tooltip: 'Use current location',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const SectionLabel('Destination'),
                      TextField(
                        controller: _destinationCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: _destinationHint,
                          errorText: _destinationError,
                          prefixIcon: const Icon(
                            Icons.place_outlined,
                            color: kAccentBlue,
                          ),
                        ),
                        onChanged: (_) {
                          _onDestinationChanged(_destinationCtrl.text);
                        },
                      ),
                      if (_loadingSuggestions) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(minHeight: 2),
                      ],
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _PlacesSuggestionList(
                          suggestions: _suggestions,
                          onSelected: _selectSuggestion,
                        ),
                      ] else if (_placesMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _placesMessage!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (_destinationWasManual &&
                          _destinationCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Select a suggestion for accurate ETA, or continue manually.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_loadingEstimate || _routeEstimate != null) ...[
                        _EstimateCard(
                          estimate: _routeEstimate,
                          loading: _loadingEstimate,
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SectionLabel('Suggested price'),
                      Row(
                        children: [
                          Expanded(
                            child: _PriceCard(
                              label: 'Minimum',
                              amount: band.minimum,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _PriceCard(
                              label: 'Maximum',
                              amount: band.maximum,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _RecommendedOfferCard(amount: band.recommended),
                      const SizedBox(height: 12),
                      _OfferSlider(
                        amount: (_offerAmount ?? band.recommended)
                            .clamp(band.minimum, band.maximum)
                            .toInt(),
                        band: band,
                        onChanged: (value) => setState(() => _setOffer(value)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _offerCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Your offer',
                          errorText: _offerError,
                          prefixText: '\$ ',
                          prefixIcon: const Icon(
                            Icons.payments_outlined,
                            color: kAccentBlue,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _offerError = value.trim().isEmpty
                                ? 'Offer amount is required'
                                : null;
                            final amount = int.tryParse(value.trim());
                            _showLowOfferWarning =
                                amount != null && amount < band.minimum;
                          });
                        },
                      ),
                      if (_showLowOfferWarning) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Below suggested minimum. You can still send it, but acceptance is less likely.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PriceChip(
                            label: 'Minimum',
                            value: band.minimum,
                            selected: _offerAmount == band.minimum,
                            onTap: () =>
                                setState(() => _setOffer(band.minimum)),
                          ),
                          _PriceChip(
                            label: 'Recommended',
                            value: band.recommended,
                            selected: _offerAmount == band.recommended,
                            onTap: () =>
                                setState(() => _setOffer(band.recommended)),
                          ),
                          _PriceChip(
                            label: 'Fast pickup',
                            value: band.fast,
                            selected: _offerAmount == band.fast,
                            onTap: () => setState(() => _setOffer(band.fast)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _OnlineDriverPreview(service: _service),
                      const SizedBox(height: 20),
                      PrimaryCtaButton(
                        label: 'Send Offer',
                        onPressed: _sendOffer,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceOption extends StatelessWidget {
  const _ServiceOption({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final ServiceType service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? kAccentBlue.withValues(alpha: 0.09)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kAccentBlue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              serviceIcon(service),
              color: selected ? kAccentBlue : Colors.grey.shade700,
            ),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                serviceLabel(service),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? kAccentBlue : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlacesSuggestionList extends StatelessWidget {
  const _PlacesSuggestionList({
    required this.suggestions,
    required this.onSelected,
  });

  final List<PlaceSuggestion> suggestions;
  final ValueChanged<PlaceSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: suggestions.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, indent: 54, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            return ListTile(
              dense: true,
              minLeadingWidth: 28,
              leading: const Icon(Icons.place_outlined, color: kAccentBlue),
              title: Text(
                suggestion.mainText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: suggestion.secondaryText.isEmpty
                  ? null
                  : Text(
                      suggestion.secondaryText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onSelected(suggestion),
            );
          },
        ),
      ),
    );
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.estimate, required this.loading});

  final RouteEstimate? estimate;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            const Icon(Icons.route, color: kAccentBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loading
                  ? 'Calculating estimate...'
                  : '${estimate!.isFallback ? 'Approx. estimate\n' : ''}'
                        'Estimated distance: ${estimate!.distanceText}\n'
                        'Estimated time: ${estimate!.durationText}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (estimate?.isFallback == true)
            Tooltip(
              message: 'Fallback estimate',
              child: Icon(Icons.info_outline, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$$amount',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RecommendedOfferCard extends StatelessWidget {
  const _RecommendedOfferCard({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAccentYellow),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF8A6D00)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Recommended offer',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '\$$amount',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _OfferSlider extends StatelessWidget {
  const _OfferSlider({
    required this.amount,
    required this.band,
    required this.onChanged,
  });

  final int amount;
  final PriceBand band;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your offer',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '\$$amount',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            min: band.minimum.toDouble(),
            max: band.maximum.toDouble(),
            divisions: math.max(1, band.maximum - band.minimum),
            value: amount.toDouble(),
            activeColor: kAccentBlue,
            inactiveColor: Colors.grey.shade300,
            label: '\$$amount',
            onChanged: (value) => onChanged(value.round()),
          ),
          Row(
            children: [
              Text(
                '\$${band.minimum}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '\$${band.maximum}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
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
      label: Text('$label - \$$value'),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: kAccentYellow.withValues(alpha: 0.5),
      checkmarkColor: Colors.black87,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: selected ? Colors.black87 : Colors.grey.shade800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    );
  }
}

class _OnlineDriverPreview extends StatelessWidget {
  const _OnlineDriverPreview({required this.service});

  final ServiceType service;

  @override
  Widget build(BuildContext context) {
    final drivers = onlineDriversFor(service);
    if (drivers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No drivers online right now - demo driver can go online from Driver mode.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }
    final driver = drivers.first;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAccentBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.radio_button_checked, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${driver.name} is online - ${driver.etaMin} min away',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class OfferMatchingScreen extends StatefulWidget {
  const OfferMatchingScreen({super.key, required this.offer});

  final OfferPayload offer;

  @override
  State<OfferMatchingScreen> createState() => _OfferMatchingScreenState();
}

class _OfferMatchingScreenState extends State<OfferMatchingScreen> {
  DriverInfo? _selectedDriver;

  void _accept() {
    final drivers = onlineDriversFor(widget.offer.service);
    if (drivers.isEmpty) {
      return;
    }
    final selected =
        _selectedDriver ??
        drivers.reduce((a, b) => a.distanceKm <= b.distanceKm ? a : b);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TrackingScreen(offer: widget.offer, driver: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drivers = onlineDriversFor(widget.offer.service);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finding drivers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.offer.id,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '${serviceLabel(widget.offer.service)} - \$${widget.offer.offerAmount}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Divider(height: 28),
            _KeyValueRow(label: 'Pickup', value: widget.offer.pickup),
            const SizedBox(height: 8),
            _KeyValueRow(label: 'Destination', value: widget.offer.destination),
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
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: kAccentBlue,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Waiting for drivers to accept your offer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              drivers.isEmpty
                  ? 'No drivers online right now'
                  : 'Online drivers',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (drivers.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'No drivers online right now - demo driver can go online from Driver mode.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    demoDriverAvailability.isOnline = true;
                    demoDriverAvailability.locationLabel =
                        'Demo driver location';
                  });
                },
                icon: const Icon(Icons.power_settings_new),
                label: const Text('Simulate driver goes online'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: kAccentBlue,
                ),
              ),
            ] else
              ...drivers.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DriverCard(
                    driver: d,
                    selected: _selectedDriver == d,
                    selectable: true,
                    onTap: () => setState(() => _selectedDriver = d),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            PrimaryCtaButton(
              label: 'Simulate Driver Accepts',
              onPressed: drivers.isEmpty ? null : _accept,
            ),
          ],
        ),
      ),
    );
  }
}

class DriverCard extends StatelessWidget {
  const DriverCard({
    super.key,
    required this.driver,
    this.selected = false,
    this.selectable = false,
    this.onTap,
  });

  final DriverInfo driver;
  final bool selected;
  final bool selectable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: selected ? 3 : 1,
      borderRadius: BorderRadius.circular(16),
      color: selected ? kAccentBlue.withValues(alpha: 0.08) : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? kAccentBlue : Colors.grey.shade200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: kAccentYellow.withValues(alpha: 0.65),
                child: Text(
                  driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.star,
                          size: 18,
                          color: Color(0xFFFFA000),
                        ),
                        Text(
                          '${driver.rating}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '- ${driver.vehicle}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${driver.distanceKm} km away - ETA ${driver.etaMin} min',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectable)
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? kAccentBlue : Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  int _stepIndex = 2;
  bool _savedHistory = false;

  DemoMapPoint get _pickupPoint => widget.offer.pickupPoint ?? kDemoPickupPoint;
  DemoMapPoint get _destinationPoint =>
      widget.offer.destinationPoint ?? kDemoDestinationPoint;

  DemoMapPoint get _driverPoint {
    final progress = (_stepIndex / (kTrackingSteps.length - 1)).clamp(0.0, 1.0);
    if (_stepIndex <= 3) {
      return DemoMapPoint.lerp(
        const DemoMapPoint(33.8898, 35.4948),
        _pickupPoint,
        progress / 0.6,
      );
    }
    return DemoMapPoint.lerp(
      _pickupPoint,
      _destinationPoint,
      (progress - 0.6).clamp(0.0, 1.0) / 0.4,
    );
  }

  void _advance() {
    if (_stepIndex >= kTrackingSteps.length - 1) {
      if (!_savedHistory) {
        demoHistory.insert(
          0,
          CompletedOffer(
            offer: widget.offer,
            driver: widget.driver,
            status: 'Completed',
          ),
        );
        _savedHistory = true;
      }
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Trip complete'),
          content: const Text('This completed offer is now saved in History.'),
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

  void _showContactDialog(String action) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action ${widget.driver.name}'),
        content: Text(
          'Demo only: this would open ${action.toLowerCase()} for your assigned driver.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = kTrackingSteps[_stepIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live trip'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DriverCard(driver: widget.driver),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showContactDialog('Call'),
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
                    onPressed: () => _showContactDialog('Message'),
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
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 178,
                child: AppMap(
                  pickup: _pickupPoint,
                  destination: _destinationPoint,
                  driver: _driverPoint,
                  routePoints: widget.offer.routePoints,
                  cameraUpdateKey: _stepIndex,
                  showRoute: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAccentBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.route, color: kAccentBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.offer.pickup} to ${widget.offer.destination} - \$${widget.offer.offerAmount}'
                          '${widget.offer.durationText == null ? '' : ' - ${widget.offer.durationText}'}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Timeline',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...List.generate(kTrackingSteps.length, (i) {
              final completed = i < _stepIndex;
              final active = i == _stepIndex;
              final pending = i > _stepIndex;
              return _TimelineRow(
                label: kTrackingSteps[i],
                completed: completed,
                active: active,
                pending: pending,
                isLast: i == kTrackingSteps.length - 1,
              );
            }),
            const SizedBox(height: 12),
            PrimaryCtaButton(label: 'Simulate next step', onPressed: _advance),
          ],
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.completed,
    required this.active,
    required this.pending,
    required this.isLast,
  });

  final String label;
  final bool completed;
  final bool active;
  final bool pending;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = completed || active ? kAccentBlue : Colors.grey.shade400;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                completed ? Icons.check_circle : Icons.radio_button_checked,
                color: color,
                size: 22,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade200),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  color: pending ? Colors.grey.shade500 : Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: demoHistory.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history,
                        size: 42,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No completed offers yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Finish a demo trip and it will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: demoHistory.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = demoHistory[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                serviceIcon(item.offer.service),
                                color: kAccentBlue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  serviceLabel(item.offer.service),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${item.offer.offerAmount}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 22),
                          _KeyValueRow(
                            label: 'Destination',
                            value: item.offer.destination,
                          ),
                          const SizedBox(height: 8),
                          _KeyValueRow(label: 'Status', value: item.status),
                          const SizedBox(height: 8),
                          _KeyValueRow(
                            label: 'Driver',
                            value: item.driver.name,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop(
                                  BookAgainPayload(
                                    service: item.offer.service,
                                    destination: item.offer.destination,
                                    offerAmount: item.offer.offerAmount,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.replay),
                              label: const Text('Book Again'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                foregroundColor: kAccentBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.userPhone,
    required this.onSignOut,
  });

  final String userPhone;
  final VoidCallback onSignOut;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _accepted = false;
  bool _rejected = false;

  OfferPayload get _previewOffer => OfferPayload(
    id: 'OPT-B-8891',
    service: ServiceType.ride,
    pickup: 'Current Location',
    destination: 'Hamra',
    offerAmount: 19,
    pickupPoint: kDemoPickupPoint,
    destinationPoint: const DemoMapPoint(33.8968, 35.4825),
  );

  Future<void> _useDriverLocation() async {
    final result = await LocationService.getCurrentLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      if (result.point != null) {
        demoDriverAvailability.location = result.point!;
        demoDriverAvailability.locationLabel = 'GPS driver location';
      } else {
        demoDriverAvailability.locationLabel = 'Default demo driver location';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ??
              (result.point != null
                  ? 'Driver location updated'
                  : 'Using default demo driver location'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = _previewOffer;
    final online = demoDriverAvailability.isOnline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver home'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Driver profile',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: kAccentYellow,
                    child: Icon(Icons.person, color: Colors.black87),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Option B Driver',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          widget.userPhone,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    online
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: online ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      online ? 'Online and visible to customers' : 'Offline',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Switch(
                    value: online,
                    onChanged: (value) {
                      setState(() {
                        demoDriverAvailability.isOnline = value;
                        if (value) {
                          _rejected = false;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Current driver location',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    demoDriverAvailability.locationLabel,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _useDriverLocation,
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Use my current location'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: kAccentBlue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!online)
              _StateMessage(
                icon: Icons.pause_circle_outline,
                text: 'Go online to receive incoming offers.',
              )
            else if (_rejected)
              _StateMessage(
                icon: Icons.block,
                text: 'Offer rejected. Waiting for the next demo offer.',
              )
            else ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _accepted ? 'Active job' : 'Incoming offer',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        o.id,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Divider(height: 24),
                      _KeyValueRow(
                        label: 'Service',
                        value: serviceLabel(o.service),
                      ),
                      const SizedBox(height: 10),
                      _KeyValueRow(label: 'Pickup', value: o.pickup),
                      const SizedBox(height: 10),
                      _KeyValueRow(label: 'Destination', value: o.destination),
                      const SizedBox(height: 10),
                      _KeyValueRow(
                        label: 'Customer offer',
                        value: '\$${o.offerAmount}',
                      ),
                      const SizedBox(height: 10),
                      const _KeyValueRow(
                        label: 'Distance/ETA',
                        value: '1.4 km - 5 min',
                      ),
                    ],
                  ),
                ),
              ),
              if (!_accepted) ...[
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Accept',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 16),
                _StateMessage(
                  icon: Icons.check_circle,
                  text: 'Accepted. Head to pickup and start the active job.',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kAccentYellow.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8A6D00)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
