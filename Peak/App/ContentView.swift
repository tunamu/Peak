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
        VStack(spacing: Spacing.xSmall) {
            Image(systemName: "flag.fill")
                .imageScale(.large)
                .foregroundStyle(.peakBrandFlag)
                .accessibilityHidden(true)
            Text("Peak")
                .font(.peakScreenTitle)
                .foregroundStyle(.peakTextPrimary)
            Text("Welcome Back")
                .font(.peakCardLabel)
                .foregroundStyle(.peakTextSecondary)
        }
        .padding(Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.peakCanvas)
    }
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    ContentView()
        .preferredColorScheme(.light)
}
