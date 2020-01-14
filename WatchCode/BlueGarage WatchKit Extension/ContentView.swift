//
//  ContentView.swift
//  BlueGarage WatchKit Extension
//
//  Created by Sarang Borude on 9/24/19.
//  Copyright © 2019 Sarang Borude. All rights reserved.
//

import SwiftUI
import Combine

struct ContentView: View {
    @State var isButtonDisabled = true
    @State var isPeripheralConnected = false
    @State var buttonScaleEffect: CGFloat = 1.0
    @State var ledScaleEffect: CGFloat = 1.0
    @State var xTranslation: CGFloat = 0.0
    @State var buttonColor: Color = Color.gray
    
    
    var animation: Animation {
        Animation.spring(dampingFraction: 0.3)
            .speed(4)
    }
    
    let gradientView = RadialGradient(gradient: .init(colors: [Color.red, Color.purple]), center: .center, startRadius: 15, endRadius: 50)
    let centralManager = WKExtension.shared().delegate as! CentralManager
    
    var body: some View {
        VStack {
            HStack {
                Text("Connection Status")
                    .frame(maxWidth: 100)
                Circle()
                    .frame(width: 30, height: 30, alignment: .trailing)
                    .foregroundColor(isPeripheralConnected ? Color.green : Color.gray)
                    .scaleEffect(ledScaleEffect)
                    .animation(.easeIn(duration: 0.4))
                    .onReceive(centralManager.bluetoothConnectionStatusPublisher, perform: { (_) in
                        withAnimation(.easeOut(duration: 0.2)) {
                            self.ledScaleEffect = 1.5
                            Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { (_) in
                                withAnimation(.easeIn(duration: 0.2)) {
                                    self.ledScaleEffect = 1.0
                                }
                            }
                        }
                    })
            }
            .frame(height: 50.0)
            
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 85, height: 85, alignment: .center)
                    .disabled(isButtonDisabled)
                    .onReceive(centralManager.bluetoothConnectionStatusPublisher, perform: { (isConnected) in
                        withAnimation(.easeIn(duration: 0.4)) {
                            if isConnected {
                                self.buttonColor = Color.red
                            } else {
                                self.buttonColor = Color.gray
                            }
                        }
                    })
                
                Text("Toggle Garage")
                    .foregroundColor(.white)
                    .frame(maxWidth: 80)
            }
            .offset(x: xTranslation, y: 0)
            .scaleEffect(buttonScaleEffect)
            .onTapGesture {
                if self.isPeripheralConnected {
                    self.garageButtonTapped()
                    withAnimation(.easeOut(duration: 0.1)) {
                        self.buttonScaleEffect = 0.75
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { (_) in
                            withAnimation(.easeIn(duration: 0.1)) {
                                self.buttonScaleEffect = 1.0
                            }
                        }
                    }
                } else {
                    
                    withAnimation(self.animation) {
                        self.xTranslation = -10.0
                        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { (_) in
                            withAnimation(self.animation) {
                                self.xTranslation = 10.0
                                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { (_) in
                                    withAnimation(self.animation) {
                                        self.xTranslation = 0.0
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onReceive(centralManager.bluetoothConnectionStatusPublisher, perform: { (isConnected) in
            self.isPeripheralConnected = isConnected
            self.isButtonDisabled = !isConnected
        })
        
    }
    
    func garageButtonTapped() {
        centralManager.writeToDevice(value: "1")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
