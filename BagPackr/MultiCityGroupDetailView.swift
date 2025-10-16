//
//  MultiCityGroupDetailView.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI
import FirebaseAuth

struct MultiCityGroupDetailView: View {
    let group: MultiCityGroupPlan
    @State private var selectedCityIndex = 0
    @State private var showAddMember = false
    
    var currentUserEmail: String {
        Auth.auth().currentUser?.email ?? ""
    }
    
    var isOwner: Bool {
        group.members.contains { $0.email == currentUserEmail && $0.isOwner }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // City tabs
            cityTabs
            
            // Selected city content
            ScrollView {
                if let selectedCity = group.multiCityItinerary.cityStops[safe: selectedCityIndex],
                   let itinerary = group.multiCityItinerary.itineraries[selectedCity.id] {
                    
                    VStack(spacing: 20) {
                        // City header
                        cityHeader(for: selectedCity)
                        
                        // Daily plans
                        ForEach(Array(itinerary.dailyPlans.enumerated()), id: \.element.id) { index, plan in
                            EnhancedDayPlanCard(
                                dayNumber: index + 1,
                                plan: plan,
                                location: selectedCity.location.name,
                                itinerary: itinerary
                            )
                        }
                    }
                    .padding()
                }
            }
            
            // Members section
            membersSection
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddMember = true }) {
                    Image(systemName: "person.badge.plus")
                }
                .disabled(!isOwner)
            }
        }
    }
    
    private var cityTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(group.multiCityItinerary.cityStops.enumerated()), id: \.element.id) { index, city in
                    CityTabButton(
                        city: city,
                        index: index + 1,
                        isSelected: selectedCityIndex == index
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            selectedCityIndex = index
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
    }
    
    private func cityHeader(for city: CityStop) -> some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                    Text(city.location.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Label("\(city.duration) days", systemImage: "calendar")
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            .padding()
        }
        .cornerRadius(20)
    }
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Members (\(group.members.count))")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(group.members, id: \.email) { member in
                        MemberBadge(member: member)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
    }
}

struct CityTabButton: View {
    let city: CityStop
    let index: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 24, height: 24)
                    
                    Text("\(index)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .blue : .white)
                }
                
                Text(city.location.name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            
            Text("\(city.duration) days")
                .font(.caption2)
                .opacity(0.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(isSelected ? Color.blue : Color.gray.opacity(0.3))
        )
    }
}

struct MemberBadge: View {
    let member: GroupMember
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(member.isOwner ? Color.purple : Color.blue)
                    .frame(width: 50, height: 50)
                
                Text(member.email.prefix(1).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(member.email.components(separatedBy: "@").first ?? "")
                .font(.caption2)
                .lineLimit(1)
                .frame(maxWidth: 60)
            
            if member.isOwner {
                Text("OWNER")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.purple)
            }
        }
    }
}
