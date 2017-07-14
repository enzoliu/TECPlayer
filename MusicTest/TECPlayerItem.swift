//
//  TECPlayerItem.swift
//  MusicTest
//
//  Created by sdcomputer on 2017/7/15.
//  Copyright © 2017年 EnzoLiu. All rights reserved.
//

import Foundation
import MediaPlayer
import AVKit


protocol TECPlayerItemDelegate {
    func tecPlayerItem(playerItem: AVPlayerItem, playable: Bool)
}

class TECPlayerItem: AVPlayerItem {
    var delegate: TECPlayerItemDelegate?
    init(url: URL) {
        // Asset loading from internet will take some times.
        // Add observer to watch status and tell delegate when process is done.
        super.init(asset: AVAsset(url:url), automaticallyLoadedAssetKeys: ["playable"])
        self.addSelfObservers()
    }
    
    deinit {
        // TODO: Need to test.
        self.removeSelfObservers()
    }
    
    func addSelfObservers() {
        self.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
    }
    
    func removeSelfObservers() {
        self.removeObserver(self, forKeyPath: "status", context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            let status: AVPlayerItemStatus
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItemStatus(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            switch status {
            case .readyToPlay:
                self.delegate?.tecPlayerItem(playerItem: self, playable: true)
                
            default:
                self.delegate?.tecPlayerItem(playerItem: self, playable: false)
            }
        }
    }
}
