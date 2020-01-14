//
//  CentralManager.swift
//  BlueGarage
//
//  Created by Sarang Borude on 9/24/19.
//  Copyright © 2019 Sarang Borude. All rights reserved.
//

import Foundation
import CoreBluetooth
import Combine
import SwiftUI

public class CentralManager: NSObject {
    // properties
    private let centralManager = CBCentralManager()
    private var peripherals = [CBPeripheral]()
    private var remotePeripheral: CBPeripheral?
    private var txCharacteristic : CBCharacteristic?
    private var rxCharacteristic : CBCharacteristic?
    private var characteristicValue = ""
    private let nc = NotificationCenter.default
    private var lightPeripheral: CBPeripheral?
    private var isPeripheralConnected = false
    private var isAppInBackground = false
    
    
    public var bluetoothConnectionStatusPublisher = PassthroughSubject<Bool, Never>()
    // HARDCODED UUIDs for the bluefruit feather
    // Not changeable for now.
    let kBLEService_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
    let kBLE_Characteristic_uuid_Tx = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
    let kBLE_Characteristic_uuid_Rx = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"
    let MaxCharacters = 20
    
    var BLEService_UUID: CBUUID
    var BLE_Characteristic_uuid_Tx: CBUUID
    var BLE_Characteristic_uuid_Rx: CBUUID
    
    
    
    public override init() {
        BLEService_UUID = CBUUID(string: kBLEService_UUID)
        BLE_Characteristic_uuid_Tx = CBUUID(string: kBLE_Characteristic_uuid_Tx)//(Property = Write without response)
        BLE_Characteristic_uuid_Rx = CBUUID(string: kBLE_Characteristic_uuid_Rx)// (Property = Read/Notify)
        
        super.init()
        centralManager.delegate = self
        //let nc = NotificationCenter.default
        //nc.addObserver(self, selector: #selector(willResignActive), name:willResignActiveNotification, object: nil)
        //nc.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    func willResignActive() {
        isAppInBackground = true
        disconnectFromDevice()
    }
    
    func didBecomeActive() {
        isAppInBackground = false
        startScan()
    }
}


// MARK: - Bluetooth Functions
public extension CentralManager {
    func startScan() {
        peripherals = []
        print("Now Scanning...")
        centralManager.scanForPeripherals(withServices: [BLEService_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        //Timer.scheduledTimer(timeInterval: 17, target: self, selector: #selector(stopScan), userInfo: nil, repeats: false)
    }
    
    @objc func stopScan() {
        self.centralManager.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripherals.count)")
    }
    
    func disconnectFromDevice () {
        guard let remotePeripheral = remotePeripheral else { return }
        centralManager.cancelPeripheralConnection(remotePeripheral)
    }
    
    func writeToDevice(value: String) {
        print("Writing to device")
        guard
            let peripheral = lightPeripheral,
            isPeripheralConnected,
            let characteristic = txCharacteristic else { return }
        print("writing \(value) to lamp........ **** Celebrations!!!")
        guard let data = value.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        
    }
}

extension CentralManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            
        case .unknown:
            break
        case .resetting:
            break
        case .unsupported:
            break
        case .unauthorized:
            break
        case .poweredOff:
            print("Bluetooth Disabled- Make sure your Bluetooth is turned on")
        case .poweredOn:
            startScan()
        @unknown default:
            break
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        stopScan()
        self.peripherals.append(peripheral)
        centralManager.connect(peripheral, options: nil)
        if remotePeripheral == nil {
            print("We found a new peripheral device with services")
            print("Peripheral name: \(String(describing: peripheral.name))")
            print("**********************************")
            print ("Advertisement Data : \(advertisementData)")
            remotePeripheral = peripheral
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        //nc.post(name: .peripheralStateChanged, object: self, userInfo: ["State": true])
        bluetoothConnectionStatusPublisher.send(true)
        print("*****************************")
        print("Connection complete")
        print("Peripheral info: \(peripheral)")
        lightPeripheral = peripheral
        isPeripheralConnected = true
        
        //Stop Scan- We don't need to scan once we've connected to a peripheral. We got what we came for.
        centralManager.stopScan()
        print("Scan Stopped")
        
        //Discovery callback
        peripheral.delegate = self
        //Only look for services that matches transmit uuid
        peripheral.discoverServices([BLEService_UUID])
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        //nc.post(name: .peripheralStateChanged, object: self, userInfo: ["State": false])
        bluetoothConnectionStatusPublisher.send(false)
        lightPeripheral = nil
        isPeripheralConnected = false
        guard !isAppInBackground else { return }
        startScan()
    }
}

extension CentralManager: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {
            
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("Discovered Services: \(services)")
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("*******************************************************")
        
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        print("Found \(characteristics.count) characteristics!")
        
        for characteristic in characteristics {
            //looks for the right characteristic
            
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Rx)  {
                rxCharacteristic = characteristic
                
                //Once found, subscribe to the this particular characteristic...
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                // We can return after calling CBPeripheral.setNotifyValue because CBPeripheralDelegate's
                // didUpdateNotificationStateForCharacteristic method will be called automatically
                peripheral.readValue(for: characteristic)
                print("Rx Characteristic: \(characteristic.uuid)")
            }
            if characteristic.uuid.isEqual(BLE_Characteristic_uuid_Tx){
                txCharacteristic = characteristic
                print("Tx Characteristic: \(characteristic.uuid)")
            }
            peripheral.discoverDescriptors(for: characteristic)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic == rxCharacteristic {
            guard let data = characteristic.value else { return }
            guard let value = String(bytes: data, encoding: .utf8) else { return }
            characteristicValue = value
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error writing to characteristic \(error)")
        }
        
        if characteristic == txCharacteristic {
            guard let data = characteristic.value else { return }
            guard let value = String(bytes: data, encoding: .utf8) else { return }
            print("wrote characteristic on Feather, value: \(value)")
        }
    }
}


extension CentralManager: WKExtensionDelegate {
//    public func applicationDidBecomeActive() {
//        print("Did become Active")
//        didBecomeActive()
//
//    }
//    public func applicationWillResignActive() {
//        willResignActive()
//         print("will resign active")
//    }
    public func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
    }

    public func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("app is active")
        didBecomeActive()
    }

    public func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        print("will resign active")
        willResignActive()
    }

    public func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
    
}
