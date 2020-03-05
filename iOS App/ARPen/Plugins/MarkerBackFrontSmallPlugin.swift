//
//  CubeByDraggingPlugin.swift
//  ARPen
//
//  Created by Philipp Wacker on 09.03.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import Foundation
import ARKit

//include the UserStudyRecordPluginProtocol to demo recording of user study data
class MarkerBackFrontSmallPlugin: Plugin, UserStudyRecordPluginProtocol {
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
    
    override init() {
        super.init()
    
        self.pluginImage = UIImage.init(named: "MarkerBackFrontSmallPlugin")
        self.pluginInstructionsImage = UIImage.init(named: "MarkerBackFrontSmallPluginInstructions")
        self.pluginIdentifier = "Small"
        self.needsBluetoothARPen = false
        self.pluginDisabledImage = UIImage.init(named: "MarkerBackFrontSmallPluginDisabled")
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
        
        let startStop = buttons[Button.Button3]!
        
        if (!started && startStop){
            self.started = true
            self.startingMillis = Date().millisecondsSince1970
            print("started")
        }
        
        if(!self.stopped && startStop && (Date().millisecondsSince1970 - self.startingMillis) > 1000){
            print("stopped")
            self.stopped = true
            scene.setPencilPointColor(r: 0.12157, g: 0.8, b: 0.12157, a: 1)
            self.recordManager.addNewRecord(withIdentifier: String(describing: type(of: self)), andData: [
            "timestamp" : "\(Date().millisecondsSince1970)",
            "penVisible" : scene.markerFound ? "true" : "false",
            "penX" : "\(scene.pencilPoint.worldPosition.x)",
            "penY" : "\(scene.pencilPoint.worldPosition.y)",
            "penZ" : "\(scene.pencilPoint.worldPosition.z)",
            "deleteButtonActive" : buttons[Button.Button2]! ? "true" : "false",
            "lineButtonActive" : buttons[Button.Button1]! ? "true" : "false",
            "startStopButtonActive" : buttons[Button.Button3]! ? "true" : "false"
            ])
        }
        
        if (self.recordManager.currentActiveUserID != nil && self.started && !self.stopped) {
            if(self.firstInit){
                scene.setPencilPointColor(r: 0.73, g: 0.12157, b: 0.8, a: 1)
                self.firstInit = false
                print("recording")
            }
                self.recordManager.addNewRecord(withIdentifier: String(describing: type(of: self)), andData: [
                    "timestamp" : "\(Date().millisecondsSince1970)",
                    "penVisible" : scene.markerFound ? "true" : "false",
                    "penX" : "\(scene.pencilPoint.worldPosition.x)",
                    "penY" : "\(scene.pencilPoint.worldPosition.y)",
                    "penZ" : "\(scene.pencilPoint.worldPosition.z)",
                    "deleteButtonActive" : buttons[Button.Button2]! ? "true" : "false",
                    "lineButtonActive" : buttons[Button.Button1]! ? "true" : "false",
                    "startStopButtonActive" : buttons[Button.Button3]! ? "true" : "false"
                    ])
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
        
        let pressed2 = buttons[Button.Button2]!
        if pressed2, !removedOneLine, let lastLine = self.previousDrawnLineNodes?.last {
            removedOneLine = true
            self.previousDrawnLineNodes?.removeLast()
            //undo last performed line if this is pressed
            for currentNode in lastLine {
                currentNode.removeFromParentNode()
            }
        } else if !pressed2, removedOneLine {
            removedOneLine = false
        }
        
        self.previousPoint = scene.pencilPoint.position
        
    }
    
    override func activatePlugin(withScene scene: PenScene, andView view: ARSCNView){
        
        super.activatePlugin(withScene: scene, andView: view)
        scene.markerBox.setModel(newmodel: Model.small)
        scene.markerBox.calculatePenTip(length: 0.140)
        previousDrawnLineNodes = [[SCNNode]]()
        scene.setPencilPointColor(r: 0.8, g: 0.73, b: 0.12157, a: 1)
        self.started = false
        self.firstInit = true
        self.stopped = false
    }
}
