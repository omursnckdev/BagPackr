//
//  InfoRow.swift
//  BagPackr
//
//  Created by Ömür Şenocak on 16.10.2025.
//

import SwiftUI

struct InfoRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
}
