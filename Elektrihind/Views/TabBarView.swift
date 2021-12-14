//
//  TabBarView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 11.12.2021.
//

import SwiftUI

struct TabBarView: View {
    @Binding var selection: Int
    @Namespace private var currentTab
    
    var body: some View {
        HStack(alignment: .bottom) {
            ForEach(tabs.indices) { index in
                GeometryReader { geometry in
                    VStack(spacing: 4) {
                        if selection == index {
//                            Color(.label)
//                                .frame(height: 2)
//                                .offset(y: -8)
//                                .matchedGeometryEffect(id: "currentTab", in: currentTab)
                        }
                        if tabs[selection].label == "Täna" && tabs[index].label == "Täna" {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .foregroundColor(Color.orange)
                        } else if tabs[selection].label == "Homme" && tabs[index].label == "Homme" {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .foregroundColor(Color.mint)
                        } else if tabs[selection].label == "Hea teada" && tabs[index].label == "Hea teada" {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .rotationEffect(.degrees(25))
                                .foregroundColor(Color.green)
                        } else if tabs[selection].label == "Seaded" && tabs[index].label == "Seaded" {
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

struct Tab {
    let image: String
    let label: String
}

let tabs = [
    Tab(image: "bolt.fill", label: "Täna"),
    Tab(image: "clock.fill", label: "Homme"),
    //Tab(image: "leaf.fill", label: "Hea teada"),
    Tab(image: "gearshape.fill", label: "Seaded"),
]

