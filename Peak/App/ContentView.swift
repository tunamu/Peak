//
//  ContentView.swift
//  Peak
//
//  Created by Tuna Mus on 29.09.2026.
//

import PeakDesign
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "figure.strengthtraining.traditional")
                .imageScale(.large)
                .foregroundStyle(DesignTokens.primary)
            Text("Peak")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
