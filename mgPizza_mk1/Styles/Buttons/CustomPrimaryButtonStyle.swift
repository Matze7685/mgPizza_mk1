//
//  CustomPrimaryButtonStyle.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 14.08.26.
//

import SwiftUI

struct NotificationButton: ButtonStyle {
    var fgColor: Color
    var bgColor: Color
    var tlRadius: CGFloat
    var blRadius: CGFloat
    var btRadius: CGFloat
    var ttRadius: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
        
            // Text-Styling
            .font(.headline)
            .foregroundColor(fgColor)
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            
            // Hintergrundfarbe & Abgerundete Ecken
            .background(
                UnevenRoundedRectangle(
                    cornerRadii:
                        RectangleCornerRadii(
                            topLeading: tlRadius,
                            bottomLeading: blRadius,
                            bottomTrailing: btRadius,
                            topTrailing: ttRadius))
                    .fill(bgColor)
            )
            // Reagiert auf den Klick-Zustand (Feedback beim Antippen)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
