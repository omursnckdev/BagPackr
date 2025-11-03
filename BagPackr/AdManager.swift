import SwiftUI
import Combine
import GoogleMobileAds
import AppTrackingTransparency

class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var interstitial: InterstitialAd?
    @Published var isAdReady = false
    @Published var shouldShowAds = true {  // ⭐ Premium kontrolü
        didSet {
            if !shouldShowAds {
                print("🚫 Ads disabled - Premium active")
                self.interstitial = nil
                self.isAdReady = false
            }
        }
    }

    static let shared = AdManager()
    
    // ⭐ Test ve Production ID'leri ayır
    #if DEBUG
    let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Test ID
    #else
    let interstitialAdUnitID = "ca-app-pub-5314394610297471/7407902751" // Production ID
    #endif
    
    override init() {
        super.init()
        configureGAD()
        
        // ⭐ Premium değişimini dinle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(premiumStatusChanged),
            name: .premiumStatusChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func configureGAD() {
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
    
    // ⭐ Premium kontrolü yap, reklam aç/kapat
    func checkPremiumAndLoadAd() {
        Task { @MainActor in
            await RevenueCatManager.shared.checkSubscriptionStatus()
            let isPremium = RevenueCatManager.shared.isSubscribed
            self.shouldShowAds = !isPremium
            
            if self.shouldShowAds {
                print("📺 Free user → Loading ads")
                self.loadAd()
            } else {
                print("👑 Premium user → No ads")
            }
        }
    }
    
    // ⭐ Premium değişimi geldiğinde
    @objc private func premiumStatusChanged() {
        print("🔔 Premium status changed → recheck ads")
        checkPremiumAndLoadAd()
    }
    
    func loadAd() {
        guard shouldShowAds else {
            print("👑 Premium user, skip ad load")
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
                    print("❌ Failed to load ad: \(error.localizedDescription)")
                    self?.isAdReady = false
                    return
                }
                
                self?.interstitial = ad
                self?.interstitial?.fullScreenContentDelegate = self
                self?.isAdReady = true
                print("✅ Interstitial ready")
            }
        }
    }
    
    func showAd() {
        guard shouldShowAds else {
            print("👑 Premium user, not showing ad")
            return
        }
        
        guard isAdReady, let interstitial = interstitial else {
            print("⚠️ Ad not ready → Loading...")
            loadAd()
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.keyWindow,
              var root = window.rootViewController else {
            print("❌ No root VC")
            return
        }
        
        while let presented = root.presentedViewController {
            root = presented
        }
        
        print("🎬 Showing interstitial ad")
        interstitial.present(from: root)
    }
    
    // MARK: - GADFullScreenContentDelegate
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("👁️ Ad impression")
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
        
        if shouldShowAds {
            loadAd()
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Failed to show ad: \(error.localizedDescription)")
        isAdReady = false
        interstitial = nil
        
        if shouldShowAds {
            loadAd()
        }
    }
}
