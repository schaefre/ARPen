//
//  MarkerPlacementPlugin.swift
//  ARPen
//
//  Created by schaefre on 01.05.20.
//  Copyright © 2020 RWTH Aachen. All rights reserved.
//

import Foundation
import ARKit

//include the UserStudyRecordPluginProtocol to demo recording of user study data
class MarkerPlacementPlugin: Plugin, UserStudyRecordPluginProtocol {
    //reference to userStudyRecordManager to add new records
    var recordManager: UserStudyRecordManager!
    
    /**
     The starting point is the point of the pencil where the button was first pressed.
     If this var is nil, there was no initial point
     */
    var penColor: UIColor = UIColor.init(red: 0.73, green: 0.12157, blue: 0.8, alpha: 1)
    /**
     The previous point is the point of the pencil one frame before.
     If this var is nil, there was no last point
     */
    private var previousPoint: SCNVector3?
    //collection of currently & last drawn line elements to offer undo
    private var previousDrawnLineNodes: [[SCNNode]]?
    private var currentLine : [SCNNode]?
    private var removedOneLine = false
    
    private var started :Bool = false
    private var firstInit :Bool = true
    private var stopped :Bool = false
    private var startingMillis :Int64 = 0
    private var stoppingMillis :Int64 = 0
    
    private var placements = [Model.back, Model.front, Model.top, Model.backfront, Model.backtop, Model.topfront, Model.small]
    
    private var currentIteration = 0
    private var training :Bool = true
    private var latinSquareID = 0
    private var finished :Bool = false
    
    private var latinSquare = [
        [0, 2, 6, 4, 5, 1, 3],
        [1, 4, 5, 2, 3, 6, 0],
        [3, 5, 1, 0, 4, 2, 6],
        [2, 0, 3, 1, 6, 4, 5],
        [6, 1, 4, 5, 0, 3, 2],
        [5, 3, 2, 6, 1, 0, 4],
        [4, 6, 0, 3, 2, 5, 1],
    ]
    
    override init() {
        super.init()
    
        self.pluginImage = UIImage.init(named: "MarkerPlacementPlugin")
        self.pluginInstructionsImage = UIImage.init(named: "MarkerPlacementPluginInstructions")
        self.pluginIdentifier = "Placements"
        self.needsBluetoothARPen = false
        self.pluginDisabledImage = UIImage.init(named: "MarkerPlacementPluginDisabled")
    }
    
    func clearScene(withScene scene: PenScene){
        previousDrawnLineNodes = [[SCNNode]]()
        scene.drawingNode.enumerateChildNodes {(node, pointer) in
            node.removeFromParentNode()
        }
    }
    
    func activateTraining(withScene scene: PenScene){
        self.training = true
        self.stopped = false
    }
    
    func prepareNextPen(withScene scene: PenScene){
        //save current data
        if let path = recordManager.urlToCSV() {
            print("Stored CSV") // + path.absoluteString
        } else {
            print("Error creating the csv!")
        }
        
        //select next pen
        currentIteration += 1
        if(currentIteration > 6){
            finished = true
            recordManager.setPluginsLocked(locked: false)
            print("Unlock plugins")
            print("Finished")
        } else {
            scene.markerBox.setModel(newmodel: placements[latinSquare[latinSquareID][currentIteration]])
            scene.markerBox.calculatePenTip(length: 0.140)
            
            //activate training
            activateTraining(withScene: scene)
        }
    }
    
    func undoPreviousAction() {
        if (self.previousDrawnLineNodes!.count > 0) {
            let lastLine = self.previousDrawnLineNodes?.last
            
            self.previousDrawnLineNodes?.removeLast()
            
            // Remove the previous line
            for currentNode in lastLine! {
                currentNode.removeFromParentNode()
            }
        }
    }
    
    override func didUpdateFrame(scene: PenScene, buttons: [Button : Bool]) {
        guard self.recordManager != nil else {return}
        
        if(self.recordManager.currentActiveUserID == nil){
            scene.setPencilPointColor(r: 1, g: 0, b: 0, a: 1)
            return
        }
        
        if(self.finished){
            scene.setPencilPointColor(r: 0, g: 1, b: 0, a: 1)
            return
        }
        
        let startStop = buttons[Button.Button3]!
        
        if (!self.started && startStop && (Date().millisecondsSince1970 - self.stoppingMillis) > 2000){
            self.started = true
            self.startingMillis = Date().millisecondsSince1970
            if(training){
                scene.setPencilPointColor(r: 0.0, g: 0.0, b: 1.0, a: 1)
                clearScene(withScene: scene)
                print("Started training with pen \(placements[latinSquare[latinSquareID][currentIteration]])")
            } else {
                print("Started trial with pen \(placements[latinSquare[latinSquareID][currentIteration]])")
            }
        }
    
        if(self.started && !self.stopped && startStop && (Date().millisecondsSince1970 - self.startingMillis) > 2000){
            self.stoppingMillis = Date().millisecondsSince1970
            if(self.training){
                self.stopped = false //it stays false because now the real trial can begin
                self.training = false
                self.started = false
                self.firstInit = true
                scene.setPencilPointColor(r: 0.8, g: 0.73, b: 0.12157, a: 1)
                clearScene(withScene: scene)
                print("Finished training with pen \(placements[latinSquare[latinSquareID][currentIteration]])")
                
            } else {
                self.stopped = true
                self.started = false
                scene.setPencilPointColor(r: 0.8, g: 0.73, b: 0.12157, a: 1)
                
                self.recordManager.addNewRecord(withIdentifier: String(describing: type(of: self)), andData: [
                "penModel": "\(placements[latinSquare[latinSquareID][currentIteration]])",
                "timestamp" : "\(Date().millisecondsSince1970)",
                "penVisible" : scene.markerFound ? "true" : "false",
                "penX" : "\(scene.pencilPoint.worldPosition.x)",
                "penY" : "\(scene.pencilPoint.worldPosition.y)",
                "penZ" : "\(scene.pencilPoint.worldPosition.z)",
                "penXRotation" : "\(scene.pencilPoint.rotation.x)",
                "penYRotation" : "\(scene.pencilPoint.rotation.y)",
                "penZRotation" : "\(scene.pencilPoint.rotation.z)",
                "deleteButtonActive" : buttons[Button.Button2]! ? "true" : "false",
                "lineButtonActive" : buttons[Button.Button1]! ? "true" : "false",
                "startStopButtonActive" : buttons[Button.Button3]! ? "true" : "false"
                ])
                
                print("Finished trial with pen \(placements[latinSquare[latinSquareID][currentIteration]])")
                prepareNextPen(withScene: scene)
            }
        }
        
        if (self.started && !self.stopped) {
            if(!self.training){
                if(self.firstInit){
                    scene.setPencilPointColor(r: 0.73, g: 0.12157, b: 0.8, a: 1)
                    self.firstInit = false
                    print("Recording")
                }
                    self.recordManager.addNewRecord(withIdentifier: String(describing: type(of: self)), andData: [
                        "penModel": "\(placements[latinSquare[latinSquareID][currentIteration]])",
                        "timestamp" : "\(Date().millisecondsSince1970)",
                        "penVisible" : scene.markerFound ? "true" : "false",
                        "penX" : "\(scene.pencilPoint.worldPosition.x)",
                        "penY" : "\(scene.pencilPoint.worldPosition.y)",
                        "penZ" : "\(scene.pencilPoint.worldPosition.z)",
                        "penXRotation" : "\(scene.pencilPoint.rotation.x)",
                        "penYRotation" : "\(scene.pencilPoint.rotation.y)",
                        "penZRotation" : "\(scene.pencilPoint.rotation.z)",
                        "deleteButtonActive" : buttons[Button.Button2]! ? "true" : "false",
                        "lineButtonActive" : buttons[Button.Button1]! ? "true" : "false",
                        "startStopButtonActive" : buttons[Button.Button3]! ? "true" : "false"
                        ])
            }
        } else {
            // for review testing disable the need to log information
            return
        }
        
        guard scene.markerFound else {
            //Don't reset the previous point to avoid disconnected lines if the marker detection failed for some frames
            //self.previousPoint = nil
            return
        }
        let pressed = buttons[Button.Button1]!
        
        if pressed, let previousPoint = self.previousPoint {
            if currentLine == nil {
                currentLine = [SCNNode]()
            }
            let cylinderNode = SCNNode()
            cylinderNode.buildLineInTwoPointsWithRotation(from: previousPoint, to: scene.pencilPoint.position, radius: 0.001, color: penColor)
            cylinderNode.name = "cylinderLine"
            scene.drawingNode.addChildNode(cylinderNode)
            //add last drawn line element to currently drawn line collection
            currentLine?.append(cylinderNode)
        } else if !pressed {
            if let currentLine = self.currentLine {
                self.previousDrawnLineNodes?.append(currentLine)
                self.currentLine = nil
            }
        }
        
        self.previousPoint = scene.pencilPoint.position
        
    }
    
    override func activatePlugin(withScene scene: PenScene, andView view: ARSCNView){
        
        super.activatePlugin(withScene: scene, andView: view)
        clearScene(withScene: scene)
        self.started = false
        self.firstInit = true
        self.stopped = false
        self.finished = false
        
        scene.setPencilPointColor(r: 0.8, g: 0.73, b: 0.12157, a: 1)
        
        if(self.recordManager != nil && self.recordManager.currentActiveUserID != nil){
            
            latinSquareID = self.recordManager.currentActiveUserID! % 7
            let id = self.recordManager.currentActiveUserID!
            print("User with id " + String(id) + " to latinSquareID " + String(latinSquareID))
            print(latinSquare[latinSquareID])
            
            scene.markerBox.setModel(newmodel: placements[latinSquare[latinSquareID][0]])
            scene.markerBox.calculatePenTip(length: 0.140)
            
            activateTraining(withScene: scene)
            currentIteration = 0
            
            recordManager.setPluginsLocked(locked: true)
            print("lock plugins")
        }
    }
}

