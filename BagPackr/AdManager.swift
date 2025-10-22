import SwiftUI
import Combine
import GoogleMobileAds
import AppTrackingTransparency

class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var interstitial: InterstitialAd?
    @Published var isAdReady = false
    @Published var shouldShowAds = true // ⭐ NEW: Premium kontrolü için
    
    static let shared = AdManager()
    
    // ⭐ UPDATED: Test ve Production ID'leri ayır
    #if DEBUG
    let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Google test ID
    let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716" // Google test banner
    #else
    let interstitialAdUnitID = "ca-app-pub-5314394610297471/7407902751" // Sizin ID
    let bannerAdUnitID = "ca-app-pub-5314394610297471/7456798743" // ⚠️ Banner ID ekleyin
    #endif
    
    override init() {
        super.init()
        configureGAD()
    }
    
    func configureGAD() {
        // GAD'i başlat
        MobileAds.shared.start { [weak self] status in
            print("✅ GAD initialized")
            self?.requestATT()
        }
    }
    
    func requestATT() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    print("ℹ️ ATT Status: \(status.rawValue)")
                    self?.checkPremiumAndLoadAd()
                }
            }
        } else {
            checkPremiumAndLoadAd()
        }
    }
    
    // ⭐ NEW: Premium kontrolü yap sonra reklam yükle
    func checkPremiumAndLoadAd() {
        Task { @MainActor in
            await RevenueCatManager.shared.checkSubscriptionStatus()
            let isPremium = RevenueCatManager.shared.isSubscribed
            self.shouldShowAds = !isPremium
            
            if self.shouldShowAds {
                print("📺 User is free tier, loading ads")
                self.loadAd()
            } else {
                print("👑 User is premium, no ads!")
            }
        }
    }
    
    // ⭐ UPDATED: Premium kontrolü ile
    func loadAd() {
        guard shouldShowAds else {
            print("👑 Premium user, skipping ad load")
            return
        }
        
        print("🔄 Loading interstitial ad...")
        let request = Request()
        
        InterstitialAd.load(
            with: interstitialAdUnitID,
            request: request
        ) { [weak self] ad, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to load: \(error.localizedDescription)")
                    self?.isAdReady = false
                    return
                }
                
                self?.interstitial = ad
                self?.interstitial?.fullScreenContentDelegate = self
                self?.isAdReady = true
                print("✅ Interstitial loaded and ready!")
            }
        }
    }
    
    // ⭐ UPDATED: Premium kontrolü ile
    func showAd() {
        guard shouldShowAds else {
            print("👑 Premium user, not showing ad")
            return
        }
        
        guard isAdReady, let interstitial = interstitial else {
            print("⚠️ Interstitial not ready yet")
            // Try loading if not ready
            loadAd()
            return
        }
        
        // Root view controller'ı bul
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.keyWindow,
              var root = window.rootViewController else {
            print("❌ Root view controller not found")
            return
        }
        
        // En üstteki view controller'ı bul
        while let presented = root.presentedViewController {
            root = presented
        }
        
        print("🎬 Presenting ad from: \(type(of: root))")
        interstitial.present(from: root)
    }
    
    // ⭐ NEW: Banner ad oluştur
    func createBannerView() -> GADBannerView? {
        guard shouldShowAds else {
            print("👑 Premium user, no banner")
            return nil
        }
        
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = bannerAdUnitID
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }
        
        let request = GADRequest()
        bannerView.load(request)
        
        print("📺 Banner ad loaded")
        return bannerView
    }
    
    // MARK: - GADFullScreenContentDelegate
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("👁️ Ad impression recorded")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("👆 Ad clicked")
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("👋 Ad will dismiss")
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ Ad dismissed")
        isAdReady = false
        interstitial = nil
        
        // Yeni reklam yükle (premium değilse)
        if shouldShowAds {
            loadAd()
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Failed to present: \(error.localizedDescription)")
        isAdReady = false
        interstitial = nil
        
        // Yeniden dene (premium değilse)
        if shouldShowAds {
            loadAd()
        }
    }
}
