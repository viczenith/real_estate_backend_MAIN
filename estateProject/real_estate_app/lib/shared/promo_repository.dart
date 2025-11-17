import 'dart:async';
import 'package:flutter/material.dart';
import 'promo_section.dart';

/// Example repository that returns promos.
/// Replace with your HTTP client / GraphQL / Firebase logic as needed.
class PromoRepository {
  /// Simulates network / DB call.
  Future<List<Promo>> fetchInitialPromos() async {
    // simulate network latency
    await Future.delayed(const Duration(milliseconds: 600));

    // Return sample promos (replace with real data fetch)
    return [
      Promo(
        id: 'p1',
        title: 'Early Bird: Save ₦1M on Guzape',
        subtitle: 'Limited units available — flexible payments.',
        imageUrl: 'assets/promo_guzape.jpg',
        endsAt: DateTime.now().add(const Duration(hours: 72)),
        ctaLabel: 'Claim Offer',
        ctaRoute: '/client-request-property',
        primaryColor: Colors.deepPurple,
        secondaryColor: Colors.pink,
      ),
      Promo(
        id: 'p2',
        title: 'Wuse Launch: New Phase',
        subtitle: 'Special rates for the first 10 buyers.',
        imageUrl: 'assets/promo_wuse.jpg',
        endsAt: DateTime.now().add(const Duration(days: 7)),
        ctaLabel: 'View Plots',
        ctaRoute: '/client-property-list',
        primaryColor: Colors.orange,
        secondaryColor: Colors.deepOrange,
      ),
    ];
  }
}
