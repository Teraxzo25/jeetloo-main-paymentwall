import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdmobHelper {
  static String get bannerID => Platform.isAndroid
      ? 'ca-app-pub-1822433308049912/2948925095'
      : 'ca-app-pub-1822433308049912/2948925095';

  static initialize() {
    MobileAds.instance.initialize();
  }

  static BannerAd getBannerAd() {
    BannerAd bAd = BannerAd(
      size: AdSize.banner,
      adUnitId: bannerID,
      listener: BannerAdListener(
        onAdClosed: (Ad ad) {},
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
        },
        onAdLoaded: (Ad ad) {},
        onAdOpened: (Ad ad) {},
      ),
      request: const AdRequest(),
    );

    return bAd;
  }
}
