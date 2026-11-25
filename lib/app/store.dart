import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'ads.dart';
import 'app_state.dart';
import '../l10n/l10n.dart';

/// Google Play purchases: "Remove Ads" (one-time, non-consumable) plus a
/// couple of consumable coin packs for the shop.
///
/// Create these in Play Console > Monetize > Products with matching IDs.
class Store extends ChangeNotifier {
  Store._();
  static final instance = Store._();

  static const removeAdsId = 'remove_ads';
  static const coins500Id = 'coins_500';
  static const coins1500Id = 'coins_1500';

  static const _consumableIds = {coins500Id, coins1500Id};
  static const _coinAmounts = {coins500Id: 500, coins1500Id: 1500};

  bool available = false;
  bool busy = false;
  final Map<String, ProductDetails> products = {};

  /// Last problem to tell the player about (cleared on the next action).
  String? message;

  StreamSubscription<List<PurchaseDetails>>? _sub;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_supported) return;
    try {
      final iap = InAppPurchase.instance;
      _sub ??= iap.purchaseStream.listen(_onPurchases,
          onError: (Object e) => debugPrint('Purchase stream error: $e'));
      available = await iap.isAvailable();
      if (!available) {
        notifyListeners();
        return;
      }
      final res = await iap.queryProductDetails(
          {removeAdsId, ..._consumableIds});
      for (final p in res.productDetails) {
        products[p.id] = p;
      }
      notifyListeners();
      // Brings back a non-consumable bought earlier (new phone, reinstall).
      await iap.restorePurchases();
    } catch (e) {
      debugPrint('Store unavailable: $e');
    }
  }

  Future<void> buyRemoveAds() => _buyNonConsumable(removeAdsId);

  Future<void> buyCoins(String productId) => _buyConsumable(productId);

  Future<void> _buyNonConsumable(String id) async {
    message = null;
    final product = products[id];
    if (!available || product == null) {
      message = 'The store is not available right now. Please try again '
          'later.';
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      busy = false;
      message = tr('The purchase could not be started.');
      notifyListeners();
    }
  }

  Future<void> _buyConsumable(String id) async {
    message = null;
    final product = products[id];
    if (!available || product == null) {
      message = 'The store is not available right now. Please try again '
          'later.';
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    try {
      await InAppPurchase.instance.buyConsumable(
          purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      busy = false;
      message = tr('The purchase could not be started.');
      notifyListeners();
    }
  }

  Future<void> restore() async {
    message = null;
    if (!available) {
      message = tr('The store is not available right now.');
      notifyListeners();
      return;
    }
    busy = true;
    notifyListeners();
    await InAppPurchase.instance.restorePurchases();
    // Restored purchases (if any) come through the stream; stop the spinner
    // after a moment either way.
    Timer(const Duration(seconds: 3), () {
      if (!busy) return;
      busy = false;
      if (!AppState.instance.adsRemoved) {
        message = tr('No earlier purchase found for this Google account.');
      }
      notifyListeners();
    });
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (p.productID == removeAdsId) {
            AppState.instance.setAdsRemoved();
            Ads.instance.removeAds();
          } else if (_coinAmounts.containsKey(p.productID)) {
            AppState.instance.addCoins(_coinAmounts[p.productID]!);
          }
          busy = false;
          break;
        case PurchaseStatus.error:
          busy = false;
          message = tr('The purchase did not go through.');
          break;
        case PurchaseStatus.canceled:
          busy = false;
          break;
        case PurchaseStatus.pending:
          message = tr('Your purchase is pending. It will complete shortly.');
          break;
      }
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
    notifyListeners();
  }
}
