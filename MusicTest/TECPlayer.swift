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
    var videoItem: TECPlayerItem?
    var audioItem: TECPlayerItem?
    var urlStatus = UrlStatus.none
    var playItemStatus = PlayItemStatus.none
    
    enum PlayItemStatus {
        case none
        case videoOK
        case audioOK
        case ok
    }
    
    enum UrlStatus {
        case none
        case avok
        case error
    }
    
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
    var isLoadCanceled = false
    var bufferLoadingQueue: [String: TECPlayerData] = [:]
    var currentPlayVideoID: String?
    var currentItemStatus = TECPlayerData.PlayItemStatus.none
    
    weak var delegate: TECPlayerDelegate?
    
    init(movieIdentifier: String) {
        super.init(contentURL: URL(string: ""))
        
        self.initVideoPlayer()
        self.initAudioPlayer()
        self.moviePlayer.stop()
        self.moviePlayer.view.isHidden = true
        if movieIdentifier != "" {
            self.playTrack(identifier: movieIdentifier, onError: nil)
        }
        
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
    
    func present(in view: VideoContainer) {
        guard let videoPlayer = self.videoPlayer else {
            return
        }
        (view.layer as! AVPlayerLayer).player = videoPlayer
        (view.layer as! AVPlayerLayer).videoGravity = AVLayerVideoGravityResizeAspect
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
                
                var artWork: MPMediaItemArtwork!
                
                if #available(iOS 10.0, *) {
                    artWork = MPMediaItemArtwork(boundsSize: CGSize(width: 400, height: 400), requestHandler: { size in
                        let img = UIImage(data: imgData)
                        guard let unwrapImg = img else {
                            return UIImage()
                        }
                        return unwrapImg
                    })
                } else {
                    artWork = MPMediaItemArtwork(image: UIImage())
                }
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
            print("playable: NO")
            return
        }
        
        // 如果聲音準備好了
        // 檢查影片好了沒
        // 如果也好了,就開始播放
        if playerItem.type == .audio {
            if self.currentItemStatus == .videoOK {
                self.currentItemStatus = .ok
                self.startStream()
            } else {
                self.currentItemStatus = .audioOK
            }
        }
        
        // 反之
        if playerItem.type == .video {
            if self.currentItemStatus == .audioOK {
                self.currentItemStatus = .ok
                self.startStream()
            } else {
                self.currentItemStatus = .videoOK
            }
        }
    }
    func startStream() {
        let audioItem = self.audioPlayer?.currentItem as! TECPlayerItem
        
        // For the issue "two times of duration", we need to set an observer to handle playEnd event.
        // Remove exist observer.
        if let observer = self.playerTimeObserver {
            self.audioPlayer?.removeTimeObserver(observer)
        }
        // Add new observer
        // 下方未必要用audioItem
        let correctTime = NSValue(time: audioItem.getCorrectDuration())
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
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTimeMake(Int64(time), 1)
        self.audioPlayer?.seek(to: cmTime)
        self.videoPlayer?.seek(to: cmTime)
    }
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
        self.cancelPlay()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    func isPlaying() -> Bool {
        guard let vp = self.videoPlayer, let ap = self.audioPlayer else {
            return false
        }
        return vp.rate > 0 || ap.rate > 0
    }
    
    func cancelPlay() {
        self.isLoadCanceled = true
    }
    
    // 預先解析某一首歌的URL
    // 解完後就預載
    // 預載後放進Queue裡
    // 播放前會先檢查Queue有沒有預載
    
    // TODO:
    // 尚未實作清除沒用的預載
    // 尚未實作取消預載
    func preloadVideo(identifier: String) {
        self.load(identifier: identifier) { [weak self] video in
            
            guard let video = video else {
                print("Video extraction failed")
                return
            }
            
            self?.bufferLoadingQueue[identifier] = video
            
            if video.urlStatus == .avok {
                let vAsset = AVURLAsset(url: video.videoURL!)
                let aAsset = AVURLAsset(url: video.audioURL!)
                
                vAsset.loadValuesAsynchronously(forKeys: ["playable"], completionHandler: {
                    let status = vAsset.statusOfValue(forKey: "playable", error: nil)
                    if status == AVKeyValueStatus.loaded {
                        let videoItem = TECPlayerItem(asset: vAsset, automaticallyLoadedAssetKeys: ["playable"])
                        videoItem.delegate = self
                        videoItem.videoID = identifier
                        videoItem.type = .video
                        self?.bufferLoadingQueue[identifier]?.videoItem = videoItem
                        
                        // 如果聲音好了,就準備完成, 如果還沒,就先宣告自己完成了
                        if self?.bufferLoadingQueue[identifier]?.playItemStatus == .audioOK {
                            self?.bufferLoadingQueue[identifier]?.playItemStatus = .ok
                        } else {
                            self?.bufferLoadingQueue[identifier]?.playItemStatus = .videoOK
                        }
                    }
                })
                
                aAsset.loadValuesAsynchronously(forKeys: ["playable"], completionHandler: {
                    let status = aAsset.statusOfValue(forKey: "playable", error: nil)
                    if status == AVKeyValueStatus.loaded {
                        let audioItem = TECPlayerItem(asset: aAsset, automaticallyLoadedAssetKeys: ["playable"])
                        audioItem.delegate = self
                        audioItem.videoID = identifier
                        audioItem.type = .audio
                        self?.bufferLoadingQueue[identifier]?.audioItem = audioItem
                        
                        // 如果影片好了,就準備完成, 如果還沒,就先宣告自己完成了
                        if self?.bufferLoadingQueue[identifier]?.playItemStatus == .videoOK {
                            self?.bufferLoadingQueue[identifier]?.playItemStatus = .ok
                        } else {
                            self?.bufferLoadingQueue[identifier]?.playItemStatus = .audioOK
                        }
                    }
                })
            }
            
        }
    }
    
    func playTrack(identifier: String, onError: ((_ error: [String: String]) -> Void)?) {
        self.currentPlayVideoID = identifier
        self.isLoadCanceled = false
        self.audioPlayer?.pause()
        self.videoPlayer?.pause()
        
        self.audioPlayer?.seek(to: kCMTimeZero)
        self.videoPlayer?.seek(to: kCMTimeZero)
        
        if let video = self.bufferLoadingQueue[identifier] {
            self.playVideo(identifier: identifier, video: video, onError: onError)
        } else {
            self.load(identifier: identifier) { [weak self] video in
                if self != nil && self!.isLoadCanceled {
                    self!.isLoadCanceled = false
                    print("load has canceled")
                    return
                }
                guard let video = video else {
                    let err = ["videoID": identifier, "msg": "Video extraction failed"]
                    onError?(err)
                    return
                }
                self?.playVideo(identifier: identifier, video: video, onError: onError)
            }
        }
    }
    
    func playVideo(identifier: String, video: TECPlayerData, onError: ((_ error: [String: String]) -> Void)?) {
        
        guard video.urlStatus != .error else {
            let err = ["videoID": identifier, "msg": "Video extraction failed"]
            onError?(err)
            return
        }
        
        guard let videoUrl = video.videoURL else {
            let err = ["videoID": identifier, "msg": "Video stream url not found"]
            onError?(err)
            return
        }
        
        guard let audioUrl = video.audioURL else {
            let err = ["videoID": identifier, "msg": "Aideo stream url not found"]
            onError?(err)
            return
        }
        
        if video.playItemStatus != .ok {
            let videoItem = TECPlayerItem(url: videoUrl)
            let audioItem = TECPlayerItem(url: audioUrl)
            
            // TODO: Need to handle both status when ready.
            audioItem.delegate = self
            audioItem.videoID = identifier
            audioItem.type = .audio
            videoItem.delegate = self
            videoItem.videoID = identifier
            videoItem.type = .video
            
            self.audioPlayer?.replaceCurrentItem(with: audioItem)
            self.videoPlayer?.replaceCurrentItem(with: videoItem)
        } else {
            self.audioPlayer?.replaceCurrentItem(with: video.audioItem)
            self.videoPlayer?.replaceCurrentItem(with: video.videoItem)
            self.startStream()
        }
        
        self.configMPInfo(data: video)
        
        if self.isInit == false {
            self.delegate?.tecPlayer(player: self, didFinishedInitializeWithResult: true)
            self.isInit = true
        }
    }
    
}
