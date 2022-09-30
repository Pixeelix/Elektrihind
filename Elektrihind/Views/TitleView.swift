//
//  TitleView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 29.09.2022.
//

import SwiftUI

struct TitleView: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.system(size: 32, weight: .medium, design: .default))
            .foregroundColor(.white)
            .padding(EdgeInsets(top: 10, leading: 20, bottom: 20, trailing: 20))
    }
}
