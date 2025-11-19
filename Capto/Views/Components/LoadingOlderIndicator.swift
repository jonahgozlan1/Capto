//
//  LoadingOlderIndicator.swift
//  Capto
//
//  Created by Refactoring on 01/27/25.
//

import SwiftUI

/// Progress indicator shown while fetching previous batches.
struct LoadingOlderIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("Loading older thoughts…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

