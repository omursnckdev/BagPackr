import SwiftUI
import Combine
import GoogleMobileAds
import AppTrackingTransparency


class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var interstitial: InterstitialAd?
    @Published var isAdReady = false
    
    static let shared = AdManager()
    
    // Test için Google'ın resmi ID'si:
    let adUnitID = "ca-app-pub-5314394610297471/7407902751" // Gerçek ID
    // let liveAdUnitID = "ca-app-pub-5314394610297471/7407902751"
    
    override init() {
        super.init()
        configureGAD()
    }
    
    func configureGAD() {
        // Test cihazını ekle
     //   MobileAds.shared.requestConfiguration.testDeviceIdentifiers =
       //     ["464c23817b0bc6d92c00cbbe0bacd6b8"]
        
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
                    self?.loadAd()
                }
            }
        } else {
            loadAd()
        }
    }
    
    func loadAd() {
        print("🔄 Loading ad...")
        let request = Request()
        
        InterstitialAd.load(
            with: adUnitID,
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
    
    func showAd() {
        guard isAdReady, let interstitial = interstitial else {
            print("⚠️ Interstitial not ready yet")
            return
        }
        
        // ✅ Root view controller'ı bul (presented olanları atla)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.keyWindow,
              var root = window.rootViewController else {
            print("❌ Root view controller not found")
            return
        }
        
        // ✅ En üstteki view controller'ı bul
        while let presented = root.presentedViewController {
            root = presented
        }
        
        print("🎬 Presenting ad from: \(type(of: root))")
        interstitial.present(from: root)
    }
    
    // MARK: - GADFullScreenContentDelegate (v12 metodları)
    
    /// ✅ v12: Reklam gösterildiğinde çağrılır (adDidPresentFullScreenContent yerine)
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        print("👁️ Ad impression recorded")
    }
    
    /// Reklama tıklandığında
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        print("👆 Ad clicked")
    }
    
    /// Reklam kapatılmadan önce
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("👋 Ad will dismiss")
    }
    
    /// Reklam kapatıldığında
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ Ad dismissed")
        isAdReady = false
        interstitial = nil
        loadAd() // Yeni reklam yükle
    }
    
    /// Reklam gösterim hatası
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Failed to present: \(error.localizedDescription)")
        isAdReady = false
        interstitial = nil
        loadAd() // Yeniden dene
    }
}
