//
//  DigitView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 10.08.26.
//


import SwiftUI

struct DigitView: View {
    //MARK:- PROPERTIES
    var time: Int
    var place: String
    
    //MARK:- BODY
    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            Text("\(time)")
                .font(.system(.title, design: .rounded))
                .fontWeight(.semibold)
            
            Text(place)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
        }
    }
}

//MARK:- PREVIEW
struct DigitView_Previews: PreviewProvider {
    static var previews: some View {
        DigitView(time: 20, place: "minutes")
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
