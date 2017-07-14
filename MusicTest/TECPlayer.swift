//
//  TECPlayer.swift
//  MusicTest
//
//  Created by EnzoLiu on 2017/7/14.
//  Copyright © 2017年 EnzoLiu. All rights reserved.
//

import Foundation
import MediaPlayer
import XCDYouTubeKit
import AVKit

protocol TECPlayerDelegate: class {
    func tecPlayer(player: TECPlayer?, didFinishedInitializeWithResult result: Bool)
}

class TECPlayer: MPMoviePlayerViewController {
    var avPlayer: AVPlayer?
    var audioPlayer: AVPlayer?
    var client: XCDYouTubeClient?
    weak var delegate: TECPlayerDelegate?
    
    init(movieIdentifier: String) {
        super.init(contentURL: URL(string: ""))
        let client = XCDYouTubeClient()
        client.getVideoWithIdentifier(movieIdentifier) { [weak self] (video, error) in
            guard let video = video else {
                print("Video extraction failed")
                self?.delegate?.tecPlayer(player: self, didFinishedInitializeWithResult: false)
                return
            }
            
            guard self?.initVideoPlayer(video) == true else {
                print("Video initialization failed")
                self?.delegate?.tecPlayer(player: self, didFinishedInitializeWithResult: false)
                return
            }
            
            guard self?.initAudioPlayer(video) == true else {
                print("Audio initialzation failed")
                self?.delegate?.tecPlayer(player: self, didFinishedInitializeWithResult: false)
                return
            }
            
            self?.configMPInfo(data: video)
            self?.moviePlayer.stop()
            self?.moviePlayer.view.isHidden = true
            self?.delegate?.tecPlayer(player: self, didFinishedInitializeWithResult: true)
        }
        
        // Observe application event
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillResignActive(notification:)), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActive(notification:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        self.client = client
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
    }
    
    func initAudioPlayer(_ video: XCDYouTubeVideo) -> Bool {
        // 140 = Audio
        guard let url = self.retrieve(URLs: video.streamURLs, ByKey: 140) else {
            return false
        }
        
        let playerItem = TECPlayerItem(url: url)
        playerItem.delegate = self
        let player = AVPlayer()
        player.replaceCurrentItem(with: playerItem)
        self.audioPlayer = player
        
        return true
    }
    
    func initVideoPlayer(_ video: XCDYouTubeVideo) -> Bool {
        // 18 = Video + Audio, 360p
        guard let url = self.retrieve(URLs: video.streamURLs, ByKey: 134) else {
            return false
        }
        
        let playerItem = TECPlayerItem(url: url)
        playerItem.delegate = self
        let player = AVPlayer()
        player.replaceCurrentItem(with: playerItem)
        self.avPlayer = player
        
        return true
    }
    
    func present(in view: UIView) {
        guard let videoPlayer = self.avPlayer else {
            return
        }
        let playerLayer = AVPlayerLayer(player: videoPlayer)
        playerLayer.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        
        if true != view.layer.sublayers?.contains(playerLayer) {
            view.layer.addSublayer(playerLayer)
        }
    }
}

// MARK:- Observe

extension TECPlayer {
    func applicationWillResignActive(notification: Notification) {
        self.avPlayer?.pause()
    }
    func applicationDidBecomeActive(notification: Notification) {
        guard let ap = self.audioPlayer else {
            return
        }
        self.avPlayer?.seek(to: ap.currentTime())
        ap.rate > 0 ? self.avPlayer?.play() : self.avPlayer?.pause()
    }
}

// MARK:- Data method

extension TECPlayer {
    func retrieve(URLs urls: [AnyHashable: URL], ByKey key: Int) -> URL? {
        let hKey = urls.keys.filter{ x in return (x as? Int) == key }.first
        guard let unwrapHKey = hKey else {
            return nil
        }
        
        guard let url = urls[unwrapHKey] else {
            return nil
        }
        
        return url
    }
    
    func configMPInfo(data: XCDYouTubeVideo) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle : data.title]
        
        if let thumbnailURL = data.largeThumbnailURL ?? data.mediumThumbnailURL ?? data.smallThumbnailURL {
            let request = URLRequest(url: thumbnailURL)
            let session = URLSession.shared
            let task = session.dataTask(with: request) { imgData, response, error in
                guard let imgData = imgData else {
                    return
                }
                
                let artWork = MPMediaItemArtwork(boundsSize: CGSize(width: 400, height: 400), requestHandler: { size in
                    let img = UIImage(data: imgData)
                    guard let unwrapImg = img else {
                        return UIImage()
                    }
                    return unwrapImg
                })
                MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                    MPMediaItemPropertyTitle : data.title,
                    MPMediaItemPropertyArtwork : artWork
                ]
            }
            task.resume()
        }
    }
}

// MARK:- Delegate

extension TECPlayer: TECPlayerItemDelegate {
    func tecPlayerItem(playerItem: AVPlayerItem, playable: Bool) {
        guard playable else {
            return
        }
        
        if UIApplication.shared.applicationState == .active {
            self.avPlayer?.play()
        }
        
        self.audioPlayer?.play()
    }
}

// MARK:- Player Control

extension TECPlayer {
    func play() {
        guard self.audioPlayer?.status == .readyToPlay && self.avPlayer?.status == .readyToPlay else {
            return
        }
        self.audioPlayer?.play()
        self.avPlayer?.play()
    }
    
    func pause() {
        self.audioPlayer?.pause()
        self.avPlayer?.pause()
    }
    
    func stop() {
        self.audioPlayer?.pause()
        self.avPlayer?.pause()
    }
    
    func isPlaying() -> Bool {
        guard let vp = self.avPlayer, let ap = self.audioPlayer else {
            return false
        }
        return vp.rate > 0 || ap.rate > 0
    }
    
    func playTrack(identifier: String) {
        self.audioPlayer?.pause()
        self.avPlayer?.pause()
        self.audioPlayer?.seek(to: kCMTimeZero)
        self.avPlayer?.seek(to: kCMTimeZero)
        
        self.client?.getVideoWithIdentifier(identifier) { [weak self] (video, error) in
            guard let video = video else {
                print("Video extraction failed")
                return
            }
            
            guard let videoUrl = self?.retrieve(URLs: video.streamURLs, ByKey: 134) else {
                print("Video stream url not found")
                return
            }
            
            guard let audioUrl = self?.retrieve(URLs: video.streamURLs, ByKey: 140) else {
                print("Aideo stream url not found")
                return
            }
            
            let videoItem = TECPlayerItem(url: videoUrl)
            let audioItem = TECPlayerItem(url: audioUrl)
            
            // TODO: Need to handle both status when ready.
            videoItem.delegate = self
            audioItem.delegate = self
            
            self?.avPlayer?.replaceCurrentItem(with: videoItem)
            self?.audioPlayer?.replaceCurrentItem(with: audioItem)
            
            self?.configMPInfo(data: video)
        }
    }
}
