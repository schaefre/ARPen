//
//  PluginManager.swift
//  ARPen
//
//  Created by Felix Wehnert on 16.01.18.
//  Copyright © 2018 RWTH Aachen. All rights reserved.
//

import ARKit

protocol PluginManagerDelegate {
    func arKitInitialiazed()
    func penConnected()
    func penFailed()
}

/**
 The PluginManager holds every plugin that is used. Furthermore the PluginManager holds the AR- and PenManager.
 */
class PluginManager: ARManagerDelegate, PenManagerDelegate {

    var arManager: ARManager
    var arPenManager: PenManager
    var buttons: [Button: Bool] = [.Button1: false, .Button2: false, .Button3: false]
    var paintPlugin: PaintPlugin
    var plugins: [Plugin]
    var pluginInstructionsCanBeHidden: [Bool]
    var activePlugin: Plugin?
    var delegate: PluginManagerDelegate?
    var experimentalPluginsStartAtIndex: Int
    var allowPluginChange = true
    
    /**
     inits every plugin
     */
    init(scene: PenScene) {
        self.paintPlugin = PaintPlugin()
        //self.plugins = [paintPlugin, MarkerBackPlugin(), CubeByDraggingPlugin(), SphereByDraggingPlugin(), CylinderByDraggingPlugin(), PyramidByDraggingPlugin(), CubeByExtractionPlugin(), ARMenusPlugin(), TranslationDemoPlugin(), CombinationPlugin(), ModelingPlugin(), SweepPluginProfileAndPath(), SweepPluginTwoProfiles(), LoftPlugin(), RevolvePluginProfileAndAxis(), RevolvePluginProfileAndCircle(), RevolvePluginTwoProfiles(), CombinePluginFunction(), CombinePluginSolidHole()]
        self.plugins = [paintPlugin, MarkerBackPlugin(), MarkerFrontPlugin(), MarkerTopPlugin(), MarkerBackFrontPlugin(), MarkerBackTopPlugin(), MarkerTopFrontPlugin(), MarkerBackFrontSmallPlugin()]
        self.pluginInstructionsCanBeHidden = Array(repeating: true, count: self.plugins.count)
        self.experimentalPluginsStartAtIndex = 0
        
        
        self.arManager = ARManager(scene: scene)
        self.arPenManager = PenManager()
        self.activePlugin = plugins.first
        self.arManager.delegate = self
        self.arPenManager.delegate = self
        
        //listen to softwarePenButton notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.softwareButtonEvent(_:)), name: .softwarePenButtonEvent, object: nil)
    }
    
    /**
     Callback from PenManager
     */
    func button(_ button: Button, pressed: Bool) {
        self.buttons[button] = pressed
    }
    
    //Callback from Notification Center. Format of userInfo: ["buttonPressed"] is the button the event is for, ["buttonState"] is the boolean whether the button is pressed or not
    @objc func softwareButtonEvent(_ notification: Notification){
        if let buttonPressed = notification.userInfo?["buttonPressed"] as? Button, let buttonState = notification.userInfo?["buttonState"] as? Bool {
            self.buttons[buttonPressed] = buttonState
        }
    }
    
    func pluginsLocked() -> Bool{
        return !self.allowPluginChange
    }
    
    func setPluginsLocked(locked: Bool){
        self.allowPluginChange = !locked
    }
    
    /**
     Callback from PenManager
     */
    func connect(successfully: Bool) {
        if successfully {
            self.delegate?.penConnected()
        } else {
            self.delegate?.penFailed()
        }
    }
    
    /**
     Callback form ARCamera
     */
    func didChangeTrackingState(cam: ARCamera) {
        switch cam.trackingState {
        case .normal:
            self.delegate?.arKitInitialiazed()
        default:
            break
        }
    }
    
    /**
     This is the callback from ARManager.
     */
    func finishedCalculation() {
        if let plugin = self.activePlugin {
            plugin.didUpdateFrame(scene: self.arManager.scene!, buttons: buttons)
        }
    }
    
    func undoPreviousStep() {
        // Todo: Add undo functionality for all plugins.
        self.paintPlugin.undoPreviousAction()
    }
}
