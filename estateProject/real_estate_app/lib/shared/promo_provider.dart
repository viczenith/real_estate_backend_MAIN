import 'package:flutter/material.dart';
import 'promo_section.dart'; 
import 'promo_repository.dart';

class PromoProvider extends ChangeNotifier {
  final List<Promo> _promos = [];
  final PromoRepository _repo;

  PromoProvider({PromoRepository? repo}) : _repo = repo ?? PromoRepository();

  List<Promo> get promos => List.unmodifiable(_promos);

  bool get hasPromos => _promos.isNotEmpty;

  void addPromo(Promo promo) {
    _promos.insert(0, promo);
    notifyListeners();
  }

  void removePromoById(String id) {
    _promos.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void replacePromos(List<Promo> newPromos) {
    _promos
      ..clear()
      ..addAll(newPromos);
    notifyListeners();
  }

  /// Loads promos from repository and replaces the internal list.
  /// Safe to call from any widget after the provider exists in the tree.
  Future<void> loadInitialPromos() async {
    try {
      final fetched = await _repo.fetchInitialPromos();
      replacePromos(fetched);
    } catch (e) {
      debugPrint('PromoProvider.loadInitialPromos error: $e');
      // optionally rethrow or handle retries
    }
  }
}
