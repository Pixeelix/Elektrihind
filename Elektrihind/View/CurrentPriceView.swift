//
//  CurrentPriceView.swift
//  Elektrihind
//
//  Created by Martin Pihooja on 29.09.2022.
//

import SwiftUI

struct CurrentPriceView: View {
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var shared: Globals
    @StateObject private var viewModel = CurrentPriceViewModel()
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top) {
                Image(shared.region.rawValue)
                    .resizable()
                    .frame(width: 40, height: 22)
                    .cornerRadius(8)
                    .shadow(radius: 5)
                Spacer()
                Text(viewModel.currenPriceTimeStamp)
                    .font(.system(size: 300))
                    .minimumScaleFactor(0.01)
            }
            .frame(height: 22)
            .padding(.top, 8)
            .padding(.leading, 10)
            .padding(.trailing, 10)
            
            VStack {
                Text(viewModel.currenPrice)
                    .font(.system(size: 300, weight: .medium))
                    .minimumScaleFactor(0.01)
            }
            .frame(height: UIScreen.is1stGenIphone ? 56 : 82)
            .padding(.top, -12)
            
            VStack {
                Text(viewModel.unit)
                    .font(.system(size: 24, weight: .medium))
            }
            Spacer()
        }
        .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.is1stGenIphone ? 120 : 140)
        .background(Color.contentBoxBackground)
        .foregroundColor(Color.bluewWhiteText)
        .cornerRadius(20)
        .onAppear {
            viewModel.setup(self.shared)
            viewModel.loadCurrentPrice()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                viewModel.setup(self.shared)
                viewModel.loadCurrentPrice()
            }
        }
    }
}
