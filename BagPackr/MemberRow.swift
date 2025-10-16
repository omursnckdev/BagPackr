//
//  MemberRow.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct MemberRow: View {
    let member: GroupMember
    let isCurrentUser: Bool
    let canRemove: Bool
    let onRemove: () -> Void
    
    var memberName: String {
        member.email.components(separatedBy: "@").first ?? member.email
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(member.isOwner ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 45, height: 45)
                
                Image(systemName: member.isOwner ? "crown.fill" : "person.fill")
                    .foregroundColor(member.isOwner ? .purple : .blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(memberName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(member.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if member.isOwner {
                        Text("• Owner")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
            
            Spacer()
            
            if canRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
            }
        }
        .padding(.vertical, 8)
    }
}
