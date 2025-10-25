import SwiftUI
import Combine
import GoogleMobileAds
import AppTrackingTransparency

class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var interstitial: InterstitialAd?
    @Published var isAdReady = false
    @Published var shouldShowAds = true {  // ⭐ NEW: Premium kontrolü
        didSet {
            if !shouldShowAds {
                print("🚫 Ads disabled - Premium active")
                self.interstitial = nil
                self.isAdReady = false
            }
        }
    }
    
    static let shared = AdManager()
    
    // ⭐ UPDATED: Test ve Production ID'leri ayır
    #if DEBUG
    let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910" // Google test ID
    #else
    let interstitialAdUnitID = "ca-app-pub-5314394610297471/7407902751" // Sizin gerçek ID
    #endif
    
    override init() {
        super.init()
        configureGAD()
        
        // ⭐ NEW: Listen for premium status changes
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
                    self?.checkPremiumAndLoadAd()  // ⭐ CHANGED: Premium kontrolü ile yükle
                }
            }
        } else {
            checkPremiumAndLoadAd()  // ⭐ CHANGED
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
    
    // ⭐ NEW: Notification handler
    @objc private func premiumStatusChanged() {
        print("🔔 AdManager received premium status change")
        checkPremiumAndLoadAd()
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
            loadAd() // Try loading if not ready
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
    
    
    
    // MARK: - GADFullScreenContentDelegate (v12 metodları)
    
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
        
        // ⭐ UPDATED: Yeni reklam yükle (premium değilse)
        if shouldShowAds {
            loadAd()
        }
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Failed to present: \(error.localizedDescription)")
        isAdReady = false
        interstitial = nil
        
        // ⭐ UPDATED: Yeniden dene (premium değilse)
        if shouldShowAds {
            loadAd()
        }
    }
}
