//
//  ItineraryTabView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct ItineraryTabView: View {
    let group: GroupPlan
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                            Text(group.itinerary.location)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            let daysText = Locale.current.language.languageCode?.identifier == "tr" ? "Gün" : "Days"
                            Label("\(group.itinerary.duration) \(daysText)", systemImage: "calendar")
                            
                            Spacer()
                            let membersText = Locale.current.language.languageCode?.identifier == "tr" ? "Üye" : "Members"
                            
                            Label("\(group.members.count) \(membersText)", systemImage: "person.2")
                        }
                        .font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding()
                }
                .cornerRadius(20)
                .padding(.horizontal)
                
                ForEach(Array(group.itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                    EnhancedDayPlanCard(
                        dayNumber: index + 1,
                        plan: plan,
                        location: group.itinerary.location,
                        itinerary: group.itinerary
                    )
                }
            }
            .padding(.vertical)
        }
    }
}
