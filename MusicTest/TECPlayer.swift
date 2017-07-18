//
//  TECPlayer.swift
//  MusicTest
//
//  Created by EnzoLiu on 2017/7/14.
//  Copyright © 2017年 EnzoLiu. All rights reserved.
//

import Foundation
import MediaPlayer
import AVKit

protocol TECPlayerDelegate: class {
    func tecPlayer(player: TECPlayer?, didFinishedInitializeWithResult result: Bool)
    func didFinishedCurrentItemPlay(player: TECPlayer?)
}

struct TECPlayerData {
    var title: String
    var thumbnailURL: URL?
    var duration: TimeInterval
    var videoURL: URL?
    var audioURL: URL?
    
    init(title: String, duration: TimeInterval) {
        self.title = title
        self.duration = duration
    }
}

class TECPlayer: MPMoviePlayerViewController, XCDParser {
    var videoPlayer: AVPlayer?
    var audioPlayer: AVPlayer?
    var playerTimeObserver: Any?
    var isInit = false
    
    weak var delegate: TECPlayerDelegate?
    
    init(movieIdentifier: String) {
        super.init(contentURL: URL(string: ""))
        
        self.initVideoPlayer()
        self.initAudioPlayer()
        self.moviePlayer.stop()
        self.moviePlayer.view.isHidden = true
        self.playTrack(identifier: movieIdentifier)
        
        // Observe application event, so that we can decide let video play or not. 
        // (Audio player will keep playing in background until user pause or finished)
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillResignActive(notification:)), name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.applicationDidBecomeActive(notification:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerItemDidFinishedPlay(notification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.audioPlayer?.currentItem)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        
        if let observer = self.playerTimeObserver {
            self.audioPlayer?.removeTimeObserver(observer)
        }
    }
    
    func initAudioPlayer() {
        let player = AVPlayer()
        self.audioPlayer = player
    }
    
    func initVideoPlayer() {
        let player = AVPlayer()
        self.videoPlayer = player
    }
    
    func present(in view: UIView) {
        guard let videoPlayer = self.videoPlayer else {
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
        self.videoPlayer?.pause()
    }
    
    func applicationDidBecomeActive(notification: Notification) {
        guard let ap = self.audioPlayer else {
            return
        }
        self.videoPlayer?.seek(to: ap.currentTime())
        ap.rate > 0 ? self.videoPlayer?.play() : self.videoPlayer?.pause()
    }
    
    func playerItemDidFinishedPlay(notification: Notification) {
        self.audioPlayer?.pause()
        self.videoPlayer?.pause()
        
        self.delegate?.didFinishedCurrentItemPlay(player: self)
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
    
    func configMPInfo(data: TECPlayerData) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle : data.title,
            MPMediaItemPropertyPlaybackDuration : data.duration
        ]
        
        if let thumbnailURL = data.thumbnailURL {
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
                    MPMediaItemPropertyPlaybackDuration : data.duration,
                    MPMediaItemPropertyArtwork : artWork
                ]
            }
            task.resume()
        }
    }
}

// MARK:- Delegate

extension TECPlayer: TECPlayerItemDelegate {
    func tecPlayerItem(playerItem: TECPlayerItem, playable: Bool) {
        guard playable else {
            return
        }
        
        // For the issue "two times of duration", we need to set an observer to handle playEnd event.
        // Remove exist observer.
        if let observer = self.playerTimeObserver {
            self.audioPlayer?.removeTimeObserver(observer)
        }
        // Add new observer
        let correctTime = NSValue(time: playerItem.getCorrectDuration())
        self.playerTimeObserver = self.audioPlayer?.addBoundaryTimeObserver(forTimes: [correctTime], queue: DispatchQueue.main) {
            NotificationCenter.default.post(name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        }
        
        if UIApplication.shared.applicationState == .active {
            self.videoPlayer?.play()
        }
        
        self.audioPlayer?.play()
    }
}

// MARK:- Player Control

extension TECPlayer {
    func play() {
        guard self.audioPlayer?.status == .readyToPlay && self.videoPlayer?.status == .readyToPlay else {
            return
        }
        self.audioPlayer?.play()
        self.videoPlayer?.play()
    }
    
    func pause() {
        self.audioPlayer?.pause()
        self.videoPlayer?.pause()
    }
    
    func stop() {
        self.audioPlayer?.pause()
        self.videoPlayer?.pause()
    }
    
    func isPlaying() -> Bool {
        guard let vp = self.videoPlayer, let ap = self.audioPlayer else {
            return false
        }
        return vp.rate > 0 || ap.rate > 0
    }
    
    func playTrack(identifier: String) {
        self.audioPlayer?.pause()
        self.videoPlayer?.pause()
        
        self.audioPlayer?.seek(to: kCMTimeZero)
        self.videoPlayer?.seek(to: kCMTimeZero)
        
        self.load(identifier: identifier) { [weak self] video in
            guard let video = video else {
                print("Video extraction failed")
                return
            }
            
            guard let videoUrl = video.videoURL else {
                print("Video stream url not found")
                return
            }
            
            guard let audioUrl = video.audioURL else {
                print("Aideo stream url not found")
                return
            }
            
            let videoItem = TECPlayerItem(url: videoUrl)
            let audioItem = TECPlayerItem(url: audioUrl)
            
            // TODO: Need to handle both status when ready.
            audioItem.delegate = self
            videoItem.delegate = self
            
            self?.audioPlayer?.replaceCurrentItem(with: audioItem)
            self?.videoPlayer?.replaceCurrentItem(with: videoItem)
            
            self?.configMPInfo(data: video)
            
            if self?.isInit == false {
                self?.delegate?.tecPlayer(player: self, didFinishedInitializeWithResult: true)
                self?.isInit = true
            }
        }
    }
}
