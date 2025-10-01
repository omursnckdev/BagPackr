import SwiftUI
import Combine
import GoogleMobileAds

class AdManager: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published var interstitial: InterstitialAd?
    static let shared = AdManager()
    let testAdUnitID = "ca-app-pub-5314394610297471/7407902751"

    override init() {
        super.init()
        loadAd()
    }
    
    func loadAd() {
        let request = Request() // ✅ v12: Request instead of GADRequest
        InterstitialAd.load(
            with: "ca-app-pub-5314394610297471/7407902751", // ✅ use 'with:' not 'withAdUnitID:'
            request: request
        ) { [weak self] ad, error in
            if let error = error {
                print("❌ Failed to load interstitial: \(error.localizedDescription)")
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            print("✅ Interstitial loaded")
        }
    }
    
    func showAd() {
        guard let interstitial = interstitial,
              let root = UIApplication.shared.connectedScenes
                  .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                  .first?.rootViewController else {
            print("⚠️ Interstitial not ready")
            return
        }
        interstitial.present(from: root)
        self.interstitial = nil
        loadAd()
    }
    
    // MARK: - FullScreenContentDelegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("ℹ️ Interstitial dismissed")
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ Failed to present: \(error.localizedDescription)")
    }
}
