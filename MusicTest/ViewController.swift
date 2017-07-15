//
//  ViewController.swift
//  MusicTest
//
//  Created by EnzoLiu on 2017/7/11.
//  Copyright © 2017年 EnzoLiu. All rights reserved.
//

import UIKit
import MediaPlayer


class ViewController: UIViewController {
    weak var loadingAnimatore: UIActivityIndicatorView?
    weak var containerView: UIView?
    var tecPlayer: TECPlayer?
    var autoPlayNextTrack: Bool = true
    
    let playList: [String] = ["5J6nx6E3JvU", "OVzGw8v6huw", "O7Ahy4g9cTQ"]
    var current: Int = 0
    
    override var canBecomeFirstResponder: Bool { return true }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Init player
        let player = TECPlayer(movieIdentifier: self.playList[current])
        player.delegate = self
        self.tecPlayer = player
        
        
        // Init layout
        self.layout()
        
        
        // Init config
        self.configRemoteControl()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func layout() {
        let fullWidth = UIScreen.main.bounds.width
        let videoHeight = fullWidth / 16 * 9
        
        self.view.backgroundColor = .white
        
        // Video container view
        let container = UIView(frame: CGRect(x: 0, y: 0, width: fullWidth, height: videoHeight))
        container.center = CGPoint(x: fullWidth / 2, y: UIScreen.main.bounds.height / 2)
        self.view.addSubview(container)
        self.containerView = container
        
        // Loading view
        let loadingAnimator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        loadingAnimator.hidesWhenStopped = true
        loadingAnimator.startAnimating()
        loadingAnimator.center = CGPoint(x: fullWidth / 2, y: UIScreen.main.bounds.height / 2)
        self.view.addSubview(loadingAnimator)
        self.loadingAnimatore = loadingAnimator
    }
}

// MARK:- TECPlayer delegate

extension ViewController: TECPlayerDelegate {
    func tecPlayer(player: TECPlayer?, didFinishedInitializeWithResult result: Bool) {
        if result {
            guard let container = self.containerView else {
                return
            }
            self.loadingAnimatore?.stopAnimating()
            player?.present(in: container)
        }
    }
}

// MARK:- Remote control

extension ViewController {
    func configRemoteControl() {
        let mrc = MPRemoteCommandCenter.shared()
        
        mrc.nextTrackCommand.isEnabled = true
        mrc.nextTrackCommand.addTarget(handler: self.nextTrackCommand(event:))
        
        mrc.previousTrackCommand.isEnabled = true
        mrc.previousTrackCommand.addTarget(handler: self.previousTrackCommand(event:))
        
        mrc.playCommand.addTarget(handler: self.playCommend(event:))
        mrc.pauseCommand.addTarget(handler: self.pauseCommand(event:))
        
        mrc.togglePlayPauseCommand.isEnabled = true
    }
    
    func nextTrackCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard self.current >= 0 else {
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        guard self.current < self.playList.count - 1 else {
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        self.current += 1
        self.tecPlayer?.playTrack(identifier: self.playList[self.current])
        
        return MPRemoteCommandHandlerStatus.success
    }
    
    func previousTrackCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard self.current > 0 else {
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        guard self.current < self.playList.count else {
            return MPRemoteCommandHandlerStatus.commandFailed
        }
        
        self.current -= 1
        self.tecPlayer?.playTrack(identifier: self.playList[self.current])
        
        return MPRemoteCommandHandlerStatus.success
    }
    
    func playCommend(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.tecPlayer?.play()
        return MPRemoteCommandHandlerStatus.success
    }
    
    func pauseCommand(event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        self.tecPlayer?.pause()
        return MPRemoteCommandHandlerStatus.success
    }
}


