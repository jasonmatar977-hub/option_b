import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Shared delivery fee calculator used by Marketplace and Butler.
///
/// Pricing tiers (per km):
///   0 – 10 km  :  $0.65 / km
///   above 10 km:  first 10 km at $0.65 + remaining at $0.55
class DeliveryPricingService {
  const DeliveryPricingService._();

  static const double _rate0to10 = 0.65;
  static const double _rateAbove10 = 0.55;
  static const double _breakKm = 10.0;

  /// Returns the delivery fee for a given distance.
  static double calculateDeliveryFee(double distanceKm) {
    if (distanceKm <= 0) return 0;
    if (distanceKm <= _breakKm) return distanceKm * _rate0to10;
    return (_breakKm * _rate0to10) + ((distanceKm - _breakKm) * _rateAbove10);
  }

  /// Human-readable label for the rate tier applied.
  static String rateType(double distanceKm) =>
      distanceKm <= _breakKm ? 'flat_0_10km' : 'tiered_above_10km';

  /// Formats an amount to 2 decimal places (e.g. "3.25").
  static String formatMoney(double amount) => amount.toStringAsFixed(2);

  /// Haversine distance between two WGS-84 coordinates, in kilometres.
  static double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final distKm = earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    if (kDebugMode) {
      debugPrint(
        '[DeliveryPricing] ${distKm.toStringAsFixed(2)} km'
        ' → \$${calculateDeliveryFee(distKm).toStringAsFixed(2)}'
        ' (${rateType(distKm)})',
      );
    }
    return distKm;
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
