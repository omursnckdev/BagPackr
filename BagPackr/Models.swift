//
//  Models.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 3.10.2025.
//

import Foundation
import SwiftUI
import FirebaseCore
import GoogleMaps
import GooglePlaces
import MapKit
import Combine
import GoogleMobileAds
// MARK: - Models
struct LocationData: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
}

struct Itinerary: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let location: String
    let duration: Int
    let interests: [String]
    let dailyPlans: [DailyPlan]
    let budgetPerDay: Double
    let createdAt: Date
    var isShared: Bool = false
    
    init(id: String = UUID().uuidString,
         userId: String,
         location: String,
         duration: Int,
         interests: [String],
         dailyPlans: [DailyPlan],
         budgetPerDay: Double = 1000,
         createdAt: Date = Date(),
         isShared: Bool = false) {
        self.id = id
        self.userId = userId
        self.location = location
        self.duration = duration
        self.interests = interests
        self.dailyPlans = dailyPlans
        self.budgetPerDay = budgetPerDay
        self.createdAt = createdAt
        self.isShared = isShared
    }
    
    static func == (lhs: Itinerary, rhs: Itinerary) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct DailyPlan: Identifiable, Codable {
    let id: String
    let day: Int
    let activities: [Activity]
    
    init(id: String = UUID().uuidString, day: Int, activities: [Activity]) {
        self.id = id
        self.day = day
        self.activities = activities
    }
}

struct Activity: Identifiable, Codable {
    let id: String
    let name: String
    let type: String
    let description: String
    let time: String
    let distance: Double
    let cost: Double
    var coordinate: CLLocationCoordinate2D?
    
    init(id: String = UUID().uuidString, name: String, type: String, description: String, time: String, distance: Double, cost: Double = 0, coordinate: CLLocationCoordinate2D? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.description = description
        self.time = time
        self.distance = distance
        self.cost = cost
        self.coordinate = coordinate
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, description, time, distance, cost
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        description = try container.decode(String.self, forKey: .description)
        time = try container.decode(String.self, forKey: .time)
        distance = try container.decode(Double.self, forKey: .distance)
        cost = try container.decode(Double.self, forKey: .cost)
        coordinate = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(description, forKey: .description)
        try container.encode(time, forKey: .time)
        try container.encode(distance, forKey: .distance)
        try container.encode(cost, forKey: .cost)
    }
}

struct GroupPlan: Identifiable, Codable {
    let id: String
    let name: String
    let itinerary: Itinerary
    let members: [GroupMember]
    let memberEmails: [String] // For Firestore querying
    let createdAt: Date
    
    init(id: String = UUID().uuidString, name: String, itinerary: Itinerary, members: [GroupMember], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.itinerary = itinerary
        self.members = members
        self.memberEmails = members.map { $0.email } // Extract emails for querying
        self.createdAt = createdAt
    }
}

struct GroupMember: Codable,Equatable {
    let email: String
    let isOwner: Bool
    
    init(email: String, isOwner: Bool = false) {
        self.email = email
        self.isOwner = isOwner
    }
}
struct GroupExpense: Identifiable, Codable {
    let id: String
    let groupId: String
    let description: String
    let amount: Double
    let paidBy: String
    let splitBetween: [String]
    let category: ExpenseCategory
    let date: Date
    let activityId: String?
    
    init(id: String = UUID().uuidString,
         groupId: String,
         description: String,
         amount: Double,
         paidBy: String,
         splitBetween: [String],
         category: ExpenseCategory = .other,
         date: Date = Date(),
         activityId: String? = nil) {
        self.id = id
        self.groupId = groupId
        self.description = description
        self.amount = amount
        self.paidBy = paidBy
        self.splitBetween = splitBetween
        self.category = category
        self.date = date
        self.activityId = activityId
    }
}

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case accommodation = "Accommodation"
    case food = "Food & Drinks"
    case transportation = "Transportation"
    case activities = "Activities"
    case shopping = "Shopping"
    case other = "Other"

    var id: Self { self }

    var localizedName: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }

    var icon: String {
        switch self {
        case .accommodation: return "bed.double.fill"
        case .food: return "fork.knife"
        case .transportation: return "car.fill"
        case .activities: return "ticket.fill"
        case .shopping: return "bag.fill"
        case .other: return "creditcard.fill"
        }
    }

    var color: Color {
        switch self {
        case .accommodation: return .blue
        case .food: return .orange
        case .transportation: return .green
        case .activities: return .purple
        case .shopping: return .pink
        case .other: return .gray
        }
    }
}



struct Balance {
    let person: String
    var amount: Double
}

struct Settlement: Identifiable, Codable {
    let id: String
    let from: String
    let to: String
    let amount: Double

    init(id: String = UUID().uuidString, from: String, to: String, amount: Double) {
        self.id = id
        self.from = from
        self.to = to
        self.amount = amount
    }
}
