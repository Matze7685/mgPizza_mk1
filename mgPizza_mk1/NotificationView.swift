//
//  TimerView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 13.08.26.
//

import SwiftUI

struct NotificationView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 300, height: 120)
                .overlay {
                    VStack {
                        Spacer()
                        Text("Dough Timer Finish")
                            .font(.system(size: 20))
                            .padding()
                        Spacer()
                        HStack {
                            Button("OK") {
                                
                            }
                            .buttonStyle(NotificationButton(
                                fgColor: Color.black,
                                bgColor: Color.black.opacity(0.3),
                                tlRadius: 0,
                                blRadius: 30,
                                btRadius: 30,
                                ttRadius: 0))
                        }
                    }
                }
        }
    }
}

#Preview {
    NotificationView()
}
