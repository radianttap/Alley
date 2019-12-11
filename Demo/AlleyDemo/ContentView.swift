//
//  ContentView.swift
//  AlleyDemo
//
//  Created by Aleksandar Vacić on 12/11/19.
//  Copyright © 2019 Radiant Tap. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	@ObservedObject var dataManager: DataManager

    var body: some View {
		List {
			ForEach(dataManager.zens, id: \.self) {
				z in
				Text(z)
			}
		}
    }
}
