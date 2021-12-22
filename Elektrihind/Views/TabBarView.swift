//
//  TabBarView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 11.12.2021.
//

import SwiftUI

struct Tab {
    let image: String
    let label: String
}

struct TabBarView: View {
    @Binding var selection: Int
    @Namespace private var currentTab
    
    @State var tabs = [ 
        Tab(image: "bolt.fill", label: localizedString("LABLE_TODAY")),
        Tab(image: "clock.fill", label: localizedString("LABLE_TOMORROW")),
        //Tab(image: "leaf.fill", label: "Hea teada"),
        Tab(image: "gearshape.fill", label: localizedString("LABLE_SETTINGS")),
    ]
    
    var body: some View {
        HStack(alignment: .bottom) {
            ForEach(tabs.indices) { index in
                GeometryReader { geometry in
                    VStack(spacing: 4) {
                        if tabs[selection].label == localizedString("LABLE_TODAY") && tabs[index].label == localizedString("LABLE_TODAY") {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .foregroundColor(Color.orange)
                        } else if tabs[selection].label == localizedString("LABLE_TOMORROW") && tabs[index].label == localizedString("LABLE_TOMORROW") {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .foregroundColor(Color.mint)
                        } else if tabs[selection].label == "Hea teada" && tabs[index].label == "Hea teada" {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .rotationEffect(.degrees(25))
                                .foregroundColor(Color.green)
                        } else if tabs[selection].label == localizedString("LABLE_SETTINGS") && tabs[index].label == localizedString("LABLE_SETTINGS") {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .foregroundColor(Color.brown)
                        } else {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .rotationEffect(.degrees(0))
                        }
                        Text(tabs[index].label)
                            .font(.caption2)
                            .fixedSize()
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: geometry.size.width / 1.34, height: 44, alignment: .bottom)
                    .padding(.horizontal)
                    .foregroundColor(selection == index ? Color(.label) : .secondary)
                    .onTapGesture {
                        withAnimation {
                            selection = index
                        }
                    }
                }
                .frame(height: 44, alignment: .bottom)
            }
        }
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView(selection: Binding.constant(0))
            .previewLayout(.sizeThatFits)
    }
}

