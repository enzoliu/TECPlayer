//
//  XCDParser.swift
//  MusicTest
//
//  Created by EnzoLiu on 2017/7/18.
//  Copyright © 2017年 EnzoLiu. All rights reserved.
//

import Foundation
import XCDYouTubeKit

// TODO: Fill all case according to youtube codec table.
enum YouTubeQuality: Int {
    case movie360p = 18
    case video = 134
    case audio = 140
}

protocol XCDParser: class {
    func load(identifier: String, callback:@escaping (_ data: TECPlayerData?) -> Void)
    func retrieve(URLs urls: [AnyHashable: URL], ByKey key: Int) -> URL?
}

extension XCDParser {
    func load(identifier: String, callback:@escaping (_ data: TECPlayerData?) -> Void) {
        let client = XCDYouTubeClient()
        client.getVideoWithIdentifier(identifier) { video, error in
            var errorData = TECPlayerData(title: "", duration: 0)
            errorData.urlStatus = .error
            guard let video = video else {
                callback(errorData)
                return
            }
            
            guard let videoURL = self.retrieve(URLs: video.streamURLs, ByKey: YouTubeQuality.video.rawValue) else {
                callback(errorData)
                return
            }
            
            guard let audioURL = self.retrieve(URLs: video.streamURLs, ByKey: YouTubeQuality.audio.rawValue) else {
                callback(errorData)
                return
            }
            
            var rtnData = TECPlayerData(title: video.title, duration: video.duration)
            rtnData.audioURL = audioURL
            rtnData.videoURL = videoURL
            rtnData.thumbnailURL = video.largeThumbnailURL ?? video.mediumThumbnailURL ?? video.smallThumbnailURL
            rtnData.urlStatus = .avok
            callback(rtnData)
        }
    }
    
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
}
