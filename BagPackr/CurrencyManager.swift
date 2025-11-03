//
//  CurrencyManager.swift
//  BagPackr
//
//  Created by Ömür Şenocak
//

import Foundation
import Combine

class CurrencyManager: ObservableObject {
    static let shared = CurrencyManager()
    
    @Published var selectedCurrency: Currency = .usd
    
    private let defaults = UserDefaults.standard
    private let currencyKey = "selectedCurrency"
    
    // Popüler para birimleri
    let availableCurrencies: [Currency] = [
        .usd, .eur, .gbp, .try_, .jpy, .cny, .inr, .krw, .aud, .cad,
        .chf, .sek, .nzd, .mxn, .sgd, .hkd, .nok, .dkk, .zar, .thb
    ]
    
    private init() {
        loadSavedCurrency()
    }
    
    func loadSavedCurrency() {
        if let savedCode = defaults.string(forKey: currencyKey),
           let currency = Currency.allCases.first(where: { $0.code == savedCode }) {
            selectedCurrency = currency
        }
    }
    
    func selectCurrency(_ currency: Currency) {
        selectedCurrency = currency
        defaults.set(currency.code, forKey: currencyKey)
    }
    
    func format(_ amount: Double, currency: Currency? = nil) -> String {
        let curr = currency ?? selectedCurrency
        return "\(curr.symbol)\(String(format: "%.0f", amount))"
    }
    
    func formatDetailed(_ amount: Double, currency: Currency? = nil) -> String {
        let curr = currency ?? selectedCurrency
        return "\(curr.symbol)\(String(format: "%.2f", amount)) \(curr.code)"
    }
}

enum Currency: String, CaseIterable, Codable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case try_ = "TRY"
    case jpy = "JPY"
    case cny = "CNY"
    case inr = "INR"
    case krw = "KRW"
    case aud = "AUD"
    case cad = "CAD"
    case chf = "CHF"
    case sek = "SEK"
    case nzd = "NZD"
    case mxn = "MXN"
    case sgd = "SGD"
    case hkd = "HKD"
    case nok = "NOK"
    case dkk = "DKK"
    case zar = "ZAR"
    case thb = "THB"
    
    var code: String {
        return self.rawValue
    }
    
    var symbol: String {
        switch self {
        case .usd, .aud, .cad, .mxn, .sgd, .hkd, .nzd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .try_: return "₺"
        case .jpy, .cny: return "¥"
        case .inr: return "₹"
        case .krw: return "₩"
        case .chf: return "Fr"
        case .sek, .nok, .dkk: return "kr"
        case .zar: return "R"
        case .thb: return "฿"
        }
    }
    
    var name: String {
        switch self {
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .try_: return "Turkish Lira"
        case .jpy: return "Japanese Yen"
        case .cny: return "Chinese Yuan"
        case .inr: return "Indian Rupee"
        case .krw: return "South Korean Won"
        case .aud: return "Australian Dollar"
        case .cad: return "Canadian Dollar"
        case .chf: return "Swiss Franc"
        case .sek: return "Swedish Krona"
        case .nzd: return "New Zealand Dollar"
        case .mxn: return "Mexican Peso"
        case .sgd: return "Singapore Dollar"
        case .hkd: return "Hong Kong Dollar"
        case .nok: return "Norwegian Krone"
        case .dkk: return "Danish Krone"
        case .zar: return "South African Rand"
        case .thb: return "Thai Baht"
        }
    }
    
    var flag: String {
        switch self {
        case .usd: return "🇺🇸"
        case .eur: return "🇪🇺"
        case .gbp: return "🇬🇧"
        case .try_: return "🇹🇷"
        case .jpy: return "🇯🇵"
        case .cny: return "🇨🇳"
        case .inr: return "🇮🇳"
        case .krw: return "🇰🇷"
        case .aud: return "🇦🇺"
        case .cad: return "🇨🇦"
        case .chf: return "🇨🇭"
        case .sek: return "🇸🇪"
        case .nzd: return "🇳🇿"
        case .mxn: return "🇲🇽"
        case .sgd: return "🇸🇬"
        case .hkd: return "🇭🇰"
        case .nok: return "🇳🇴"
        case .dkk: return "🇩🇰"
        case .zar: return "🇿🇦"
        case .thb: return "🇹🇭"
        }
    }
}
