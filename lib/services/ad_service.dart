import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _adsRemoved = false;
  int _levelsSinceAd = 0;
  
  // Test Ad Unit IDs - Replace with your real IDs for production
  static const String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  
  // IAP Product ID
  static const String removeAdsProductId = 'remove_ads';
  
  bool get adsRemoved => _adsRemoved;
  
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    await _loadAdsRemovedState();
    if (!_adsRemoved) {
      _loadInterstitialAd();
      _loadRewardedAd();
    }
  }
  
  Future<void> _loadAdsRemovedState() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool('adsRemoved') ?? false;
  }
  
  Future<void> setAdsRemoved(bool value) async {
    _adsRemoved = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adsRemoved', value);
  }
  
  void _loadInterstitialAd() {
    if (_adsRemoved) return;
    
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
          // Retry after delay
          Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }
  
  void _loadRewardedAd() {
    if (_adsRemoved) return;
    
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }
  
  // Call this after each level
  void onLevelComplete() {
    if (_adsRemoved) return;
    _levelsSinceAd++;
  }
  
  // Show interstitial every 3 levels
  Future<bool> showInterstitialIfReady() async {
    if (_adsRemoved) return false;
    if (_levelsSinceAd < 3) return false;
    
    if (_interstitialAd != null) {
      _levelsSinceAd = 0;
      await _interstitialAd!.show();
      return true;
    }
    return false;
  }
  
  // Show rewarded ad for bonus
  Future<bool> showRewardedAd(Function(int) onRewarded) async {
    if (_rewardedAd != null) {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          onRewarded(reward.amount.toInt());
        },
      );
      return true;
    }
    return false;
  }
  
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}

// IAP Service
class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();
  
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _available = false;
  
  static const Set<String> _productIds = {AdService.removeAdsProductId};
  
  bool get available => _available;
  List<ProductDetails> get products => _products;
  
  Future<void> initialize() async {
    _available = await _iap.isAvailable();
    if (!_available) return;
    
    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('IAP Error: $error'),
    );
    
    // Load products
    final response = await _iap.queryProductDetails(_productIds);
    _products = response.productDetails;
  }
  
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Verify and deliver
        if (purchase.productID == AdService.removeAdsProductId) {
          await AdService().setAdsRemoved(true);
        }
        
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }
    }
  }
  
  Future<bool> buyRemoveAds() async {
    if (!_available || _products.isEmpty) return false;
    
    final product = _products.firstWhere(
      (p) => p.id == AdService.removeAdsProductId,
      orElse: () => _products.first,
    );
    
    final purchaseParam = PurchaseParam(productDetails: product);
    return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }
  
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }
  
  void dispose() {
    _subscription?.cancel();
  }
}
