//
//  DeviceViewController.swift
//  SwiftStarter
//
//  Created by Stephen Schiffli on 10/20/15.
//  Copyright © 2015 MbientLab Inc. All rights reserved.
//

import UIKit
import MetaWear
import CoreMotion
import AVFoundation

class DeviceViewController: UIViewController {
    
    @IBOutlet weak var deviceStatus: UILabel!
    @IBOutlet weak var headView: headViewController!
    
    let PI : Double = 3.14159265359
    var bigX: Double = 0
    var bigY: Double = 0
    var bigZ: Double = 0
    var device: MBLMetaWear!
    var seagullTimer : Timer?
    var startTime : TimeInterval?
    
    var motionGyroManager = CMMotionManager()
    
    var isPlaying: Bool = false
    
    var playSoundsController : PlaySoundsController!
    var environment : Environment!
    
    struct Environment {
        var name: String
        var indexStart: Int
        var numberOfSounds: Int
    }
    
    
    var seagullX : Float = -50
    var seagullY : Float = 20
    var seagullZ : Float = -5
    var seagullDX: Float = 0.1  //refers to change in x
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
        device.addObserver(self, forKeyPath: "state", options: NSKeyValueObservingOptions.new, context: nil)
        device.connectAsync().success { _ in
            self.device.led?.flashColorAsync(UIColor.green, withIntensity: 1.0, numberOfFlashes: 3)
            NSLog("We are connected")
        }
        // load Forest Environemnt into struc
    }
    
    func loadDics(_ data: [String: Float]) {
        let pitch = data["pitch"]
        let yaw = data["yaw"]
        let roll = data["roll"]
        
        var degree = degrees(Double(yaw!))
        if (playSoundsController != nil){
            playSoundsController.updateAngularOrientation(Float(degrees(Double(yaw!))))
        }
        if (degrees(Double(yaw!)) < 0) {
            degree = abs(degrees(Double(yaw!)))
            if (degree <= 90) {
                degree = 360 - degree
            }
            else if (degree > 90) {
                degree = 180 - degree + 180
            }
        }
        else {
            degree = degrees(Double(yaw!))
        }
        playSoundsController.updateAngularOrientation(Float(degree))
    }
    
    
    func startGyro() {
        motionGyroManager.deviceMotionUpdateInterval = 0.1
        
        motionGyroManager.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xArbitraryCorrectedZVertical, to: OperationQueue.main) {
            (motion: CMDeviceMotion?, _) in
            if let attitude: CMAttitude = motion?.attitude {
                var d = [String:Float]()
                d["roll"] = Float(attitude.roll)
                d["pitch"] = Float(attitude.pitch)
                d["yaw"] = Float(attitude.yaw)
                //print(d)
                self.loadDics(d)
            }
        }

    }
    
    @IBAction func useGyro(_ sender: UIButton) {
        stopPressed(sender: 69 as AnyObject)
        startGyro()
    }
    

    
    @IBAction func environment(_ sender: UIButton) {
        isPlaying = true
        switch sender.tag{
            
        case 0:
            //forest
            environment = Environment(name: "Forest", indexStart: 0, numberOfSounds: 3)
            //print(sender.tag)
            
        case 1:
            //beach
            environment = Environment(name: "Beach", indexStart: 3, numberOfSounds: 2)
        case 2:
            //music school
            //environment = Environment(name: "Music School", indexStart: 5, numberOfSounds: 3)
            environment = Environment(name: "Fireside", indexStart: 5, numberOfSounds: 3)
        case 3:
            //cello
            environment = Environment(name: "Cello", indexStart: 8, numberOfSounds: 12) //12
        default: break
        }
        
        loadSounds(env: environment)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        device.removeObserver(self, forKeyPath: "state")
        device.led?.flashColorAsync(UIColor.red, withIntensity: 1.0, numberOfFlashes: 3)
        device.disconnectAsync()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        OperationQueue.main.addOperation {
            switch (self.device.state) {
            case .connected:
                self.deviceStatus.text = "Connected";
                self.device.sensorFusion?.mode = MBLSensorFusionMode.imuPlus
            case .connecting:
                self.deviceStatus.text = "Connecting";
            case .disconnected:
                self.deviceStatus.text = "Disconnected";
            case .disconnecting:
                self.deviceStatus.text = "Disconnecting";
            case .discovery:
                self.deviceStatus.text = "Discovery";
            }
        }
    }
    
    func getFusionValues(obj: MBLEulerAngleData){
        
        let xS =  String(format: "%.02f", (obj.p))
        let yS =  String(format: "%.02f", (obj.y))
        let zS =  String(format: "%.02f", (obj.r))
    
        let x = radians((obj.p * -1) + 90)
        let y = radians(abs(365 - obj.y))
        let z = radians(obj.r)
        headView.setPointerPosition(w: 0.0, x : x, y: y, z: z)
        playSoundsController.updateAngularOrientation(abs(Float(365 - obj.y)))
    }
 
    func radians(_ degree: Double) -> Double {
        return ( PI/180 * degree)
    }
    func degrees(_ radian: Double) -> Double {
        return (180 * radian / PI)
    }
    
    
    @IBAction func startPressed(sender: AnyObject) {
        motionGyroManager.stopDeviceMotionUpdates()
        if (isPlaying) {
            device.sensorFusion?.eulerAngle.startNotificationsAsync { (obj, error) in
                self.getFusionValues(obj: obj!)
                }.success { result in
                    print("Successfully subscribed")
                }.failure { error in
                    print("Error on subscribe: \(error)")
            }
        }
    }
    
    @IBAction func stopPressed(sender: AnyObject) {
        device.sensorFusion?.eulerAngle.stopNotificationsAsync().success { result in
            print("Successfully unsubscribed")
            }.failure { error in
                print("Error on unsubscribe: \(error)")
        }
    }
    
    func loadSounds(env: Environment){
        var soundArray : [String] = []
        let start = env.indexStart
        let num = env.indexStart + env.numberOfSounds - 1
        for index in start...num{
            soundArray.append(String(index) + ".wav")
        }
        playSoundsController = PlaySoundsController(file: soundArray)
        stopSeagullTimer()
        
        switch env.name{
        case "Forest":
            playSoundsController.updatePosition(index: 0, position: AVAudio3DPoint(x: -50, y: 20, z: -5))
            
            //maybe can rotate around later w/timer like seagulls?
            playSoundsController.updatePosition(index: 1, position: AVAudio3DPoint(x: 0, y: 9999, z: -1))
            
            //maybe play when gyromoves?
            playSoundsController.updatePosition(index: 2, position: AVAudio3DPoint(x: 0, y: 0, z: -7.5))
            seagulls()
            
        case "Beach":
            playSoundsController.updatePosition(index: 0, position: AVAudio3DPoint(x: -50, y: 20, z: -5))
            //seagulls: maybe can rotate around later w/timer
            playSoundsController.updatePosition(index: 1, position: AVAudio3DPoint(x: 0, y: 0, z: -5))
            seagulls()
        /*case "Music School":
            playSoundsController.updatePosition(index: 0, position: AVAudio3DPoint(x: -40, y: 0, z: 0))
            playSoundsController.updatePosition(index: 1, position: AVAudio3DPoint(x: 15, y: 0, z: 15))
            playSoundsController.updatePosition(index: 2, position: AVAudio3DPoint(x: 0, y: 0, z: -15))*/
        case "Fireside":
            playSoundsController.updatePosition(index: 0, position: AVAudio3DPoint(x: -0, y: 0, z: -2))
            playSoundsController.updatePosition(index: 1, position: AVAudio3DPoint(x: -50, y: 0, z: 50))
            playSoundsController.updatePosition(index: 2, position: AVAudio3DPoint(x: 50, y: 0, z: 50))
        case "Cello":
            playSoundsController.updatePosition(index: 0, position: AVAudio3DPoint(x: 0, y: 0, z: -7.5))
            playSoundsController.updatePosition(index: 1, position: AVAudio3DPoint(x: 3.25, y: 0, z: -3.25 * sqrt(3.0)))
            playSoundsController.updatePosition(index: 2, position: AVAudio3DPoint(x: 3.25 * sqrt(3.0), y: 0, z: -3.25))
            playSoundsController.updatePosition(index: 3, position: AVAudio3DPoint(x: 7.5, y: 0, z: 0))
            playSoundsController.updatePosition(index: 4, position: AVAudio3DPoint(x: 3.25 * sqrt(3.0), y: 0, z: 3.25))
            playSoundsController.updatePosition(index: 5, position: AVAudio3DPoint(x: 3.25, y: 0, z: 3.25*sqrt(3.0)))
            playSoundsController.updatePosition(index: 6, position: AVAudio3DPoint(x: 0, y: 0, z: 7.5))
            playSoundsController.updatePosition(index: 7, position: AVAudio3DPoint(x: -3.25, y: 0, z: 3.25*sqrt(3.0)))
            playSoundsController.updatePosition(index: 8, position: AVAudio3DPoint(x: -3.25 * sqrt(3.0), y: 0, z:3.25))
            playSoundsController.updatePosition(index: 9, position: AVAudio3DPoint(x: -7.5, y: 0, z: 0))
            playSoundsController.updatePosition(index: 10, position: AVAudio3DPoint(x: -3.25 * sqrt(3.0), y: 0, z: -3.25))
            playSoundsController.updatePosition(index: 11, position: AVAudio3DPoint(x: -3.25, y: 0, z: -3.25 * sqrt(3.0)))
            
        default: break
        }

        for sounds in soundArray.enumerated(){
            // skip seagguls
            if sounds.offset != 3 {
                playSoundsController.play(index: sounds.offset)
            }
        }
    
    }
    
    func seagulls() {
        let aSelector : Selector = #selector(self.moveSoundsLinearPath)
        seagullTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: aSelector, userInfo: nil, repeats: true)
    }
    
    func moveSoundsLinearPath() {
        //print(seagullX)
        playSoundsController.updatePosition(index: 0, position: AVAudio3DPoint(x: seagullX, y: seagullY, z: seagullZ))
        seagullX += seagullDX
        if (seagullX > 60.0  || seagullX < -60.0){
            //playSoundsController.stop(index: 0)
            //stopBirdsTimer()
            seagullDX = -seagullDX
        }
    }
    
    func stopSeagullTimer() {
        if seagullTimer != nil {
            seagullTimer?.invalidate()
            seagullTimer = nil
        }
    }
}
