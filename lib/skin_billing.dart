import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'skin.dart';

typedef VerifySkinPurchase = Future<bool> Function(PurchaseDetails purchase);

class SkinBilling extends ChangeNotifier {
  SkinBilling({required this.verify, this.checkoutEnabled = false, InAppPurchase? store})
      : store = store ?? InAppPurchase.instance;
  final VerifySkinPurchase verify;
  final bool checkoutEnabled;
  final InAppPurchase store;
  final Set<String> _owned = {};
  Set<String> get owned => Set.unmodifiable(_owned);
  List<ProductDetails> products = [];
  String? error;
  bool available = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _disposed = false;
  void _changed() { if (!_disposed) notifyListeners(); }

  Future<void> initialize() async {
    _subscription ??= store.purchaseStream.listen(_handle, onError: (Object e) {
      error = '구매 상태 확인 실패'; _changed();
    });
    try {
      available = await store.isAvailable();
      if (available) {
        final response = await store.queryProductDetails(SkinStyle.premiumProducts.values.toSet());
        products = response.productDetails;
        if (response.error != null) error = '상품 조회 실패';
      }
    } catch (_) { error = '스토어 연결 실패'; }
    _changed();
  }

  Future<bool> buy(ProductDetails product) async {
    if (!checkoutEnabled || !available || !SkinStyle.premiumProducts.containsValue(product.id)) return false;
    return store.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> restore() async {
    if (checkoutEnabled && available) await store.restorePurchases();
  }

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (!SkinStyle.premiumProducts.containsValue(p.productID)) continue;
      if (p.status == PurchaseStatus.pending) { error = '구매 승인 대기 중'; continue; }
      if (p.status == PurchaseStatus.error || p.status == PurchaseStatus.canceled) {
        error = '구매가 완료되지 않았습니다'; continue;
      }
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        try {
          if (!await verify(p)) { error = '구매 검증 필요'; continue; }
          if (p.pendingCompletePurchase) await store.completePurchase(p);
          _owned.add(p.productID);
          error = null;
        } catch (_) { error = '구매 검증 또는 완료 실패'; }
      }
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
