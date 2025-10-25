//
//  MoveActivitySheet.swift
//  BagPackr
//

import SwiftUI

struct MoveActivitySheet: View {
    @Environment(\.dismiss) var dismiss
    let days: [DailyPlan]
    let currentDayIndex: Int
    let onMove: (Int) -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(days.indices, id: \.self) { index in
                    Button(action: {
                        onMove(index)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Day \(index + 1)")
                                    .font(.headline)
                                
                                Text("\(days[index].activities.count) activities")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if index == currentDayIndex {
                                Text("Current")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            } else {
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(index == currentDayIndex)
                }
            }
            .navigationTitle("Move to Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
