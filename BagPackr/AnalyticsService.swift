//
//  AnalyticsService.swift
//  BagPackr
//
//  Created by Ömür Şenocak
//

import Firebase
import FirebaseAnalytics

class AnalyticsService {
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - Screen Events
    func logScreenView(_ screenName: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenName
        ])
    }
    
    // MARK: - Authentication Events
    func logSignUp(method: String = "email") {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: method
        ])
    }
    
    func logLogin(method: String = "email") {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method
        ])
    }
    
    func logLogout() {
        Analytics.logEvent("user_logout", parameters: [:])
    }
    
    func logAccountDeleted() {
        Analytics.logEvent("account_deleted", parameters: [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
    }
    
    // MARK: - Itinerary Events
    func logItineraryCreated(
        location: String,
        duration: Int,
        interestCount: Int,
        budgetPerDay: Double,
        isPremium: Bool
    ) {
        Analytics.logEvent("itinerary_created", parameters: [
            "location": location,
            "duration": duration,
            "interest_count": interestCount,
            "budget_per_day": budgetPerDay,
            "is_premium": isPremium
        ])
    }
    
    func logItineraryViewed(itineraryId: String, location: String) {
        Analytics.logEvent("itinerary_viewed", parameters: [
            "itinerary_id": itineraryId,
            "location": location
        ])
    }
    
    func logItineraryDeleted(location: String, duration: Int) {
        Analytics.logEvent("itinerary_deleted", parameters: [
            "location": location,
            "duration": duration
        ])
    }
    
    func logItineraryShared(method: String, location: String) {
        Analytics.logEvent(AnalyticsEventShare, parameters: [
            AnalyticsParameterMethod: method,
            "location": location
        ])
    }
    
    // MARK: - Multi-City Events
    func logMultiCityCreated(
        cityCount: Int,
        totalDuration: Int,
        totalBudget: Double
    ) {
        Analytics.logEvent("multi_city_created", parameters: [
            "city_count": cityCount,
            "total_duration": totalDuration,
            "total_budget": totalBudget
        ])
    }
    
    func logCityAdded(cityName: String, duration: Int) {
        Analytics.logEvent("city_added_to_trip", parameters: [
            "city_name": cityName,
            "duration": duration
        ])
    }
    
    func logCityRemoved(cityName: String) {
        Analytics.logEvent("city_removed_from_trip", parameters: [
            "city_name": cityName
        ])
    }
    
    // MARK: - Group Events
    func logGroupCreated(memberCount: Int, isMultiCity: Bool) {
        Analytics.logEvent("group_created", parameters: [
            "member_count": memberCount,
            "is_multi_city": isMultiCity
        ])
    }
    
    func logMemberAdded(groupId: String) {
        Analytics.logEvent("member_added", parameters: [
            "group_id": groupId
        ])
    }
    
    func logMemberRemoved(groupId: String) {
        Analytics.logEvent("member_removed", parameters: [
            "group_id": groupId
        ])
    }
    
    func logGroupDeleted(memberCount: Int) {
        Analytics.logEvent("group_deleted", parameters: [
            "member_count": memberCount
        ])
    }
    
    // MARK: - Expense Events
    func logExpenseAdded(amount: Double, category: String, splitCount: Int) {
        Analytics.logEvent("expense_added", parameters: [
            "amount": amount,
            "category": category,
            "split_count": splitCount
        ])
    }
    
    func logExpenseDeleted(amount: Double) {
        Analytics.logEvent("expense_deleted", parameters: [
            "amount": amount
        ])
    }
    
    func logSettlementMarkedPaid(amount: Double) {
        Analytics.logEvent("settlement_marked_paid", parameters: [
            "amount": amount
        ])
    }
    
    // MARK: - Premium Events
    func logPremiumUpgradeShown(reason: String) {
        Analytics.logEvent("premium_alert_shown", parameters: [
            "reason": reason
        ])
    }
    
    func logPremiumPurchaseStarted() {
        Analytics.logEvent("premium_purchase_started", parameters: [:])
    }
    
    func logPremiumPurchaseCompleted(price: Double?) {
        var params: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let price = price {
            params["price"] = price
        }
        Analytics.logEvent(AnalyticsEventPurchase, parameters: params)
    }
    
    func logPremiumRestored() {
        Analytics.logEvent("premium_restored", parameters: [:])
    }
    
    // MARK: - Interest Selection
    func logInterestSelected(interest: String, isCustom: Bool) {
        Analytics.logEvent("interest_selected", parameters: [
            "interest": interest,
            "is_custom": isCustom
        ])
    }
    
    func logCustomInterestAdded(interest: String) {
        Analytics.logEvent("custom_interest_added", parameters: [
            "interest": interest
        ])
    }
    
    // MARK: - AI/Gemini Events
    func logAIGenerationStarted(type: String) {
        Analytics.logEvent("ai_generation_started", parameters: [
            "generation_type": type
        ])
    }
    
    func logAIGenerationCompleted(type: String, duration: TimeInterval) {
        Analytics.logEvent("ai_generation_completed", parameters: [
            "generation_type": type,
            "duration_seconds": Int(duration)
        ])
    }
    
    func logAIGenerationFailed(type: String, error: String) {
        Analytics.logEvent("ai_generation_failed", parameters: [
            "generation_type": type,
            "error": error
        ])
    }
    
    // MARK: - User Properties
    func setUserProperty(isPremium: Bool) {
        Analytics.setUserProperty(isPremium ? "premium" : "free", forName: "user_tier")
    }
    
    func setUserProperty(totalPlans: Int) {
        Analytics.setUserProperty("\(totalPlans)", forName: "total_plans_created")
    }
}
