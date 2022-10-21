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
    let index: Int
}

struct TabBarView: View {
    @Binding var selection: Int
    @EnvironmentObject var shared: Globals
    
    let tabs = [
        Tab(image: "bolt.fill", label: "LABEL_TODAY", index: 0),
        Tab(image: "clock.fill", label: "LABEL_TOMORROW", index: 1),
        Tab(image: "leaf.fill", label: "LABEL_ASSISTENT", index: 2),
        Tab(image: "gearshape.fill", label: "LABEL_SETTINGS", index: 3),
    ]
    
    var body: some View {
        HStack(alignment: .bottom) {
            ForEach(tabs.indices) { index in
                GeometryReader { geometry in
                    VStack(spacing: 4) {
                        if tabs[selection].index == 0 && tabs[index].index == 0  {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .foregroundColor(Color.orange)
                        } else if tabs[selection].index == 1 && tabs[index].index == 1 {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .foregroundColor(Color(red: 102/255, green: 212/255, blue: 207/255))
                        } else if tabs[selection].index == 2 && tabs[index].index == 2 {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .rotationEffect(.degrees(25))
                                .foregroundColor(Color.green)
                        } else if tabs[selection].index == 3 && tabs[index].index == 3 {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .foregroundColor(Color(red: 172/255, green: 142/255, blue: 104/255))
                        } else {
                            Image(systemName: tabs[index].image)
                                .frame(height: 20)
                                .rotationEffect(.degrees(0))
                        }
                        Text(shared.localizedString(tabs[index].label))
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
    static let shared = Globals()
    static var previews: some View {
        TabBarView(selection: Binding.constant(0))
            .previewLayout(.sizeThatFits)
            .environmentObject(shared)
    }
}
