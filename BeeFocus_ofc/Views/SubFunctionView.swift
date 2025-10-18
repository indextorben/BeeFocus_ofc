//
//  SubFunctionView.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//
import SwiftUI
import AVKit

struct SubFunctionView: View {
    let data: SubFunctionData
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(data.title)
                    .font(.largeTitle.bold())
                    .padding()
                
                Text(data.text)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                // Bullet Points
                if let bullets = data.bulletPoints, !bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(bullets, id: \.self) { point in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(point)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle(data.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
