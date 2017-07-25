//
//  VideoContainer.swift
//  MoPartyLa
//
//  Created by 鄭傑文 on 2017/7/24.
//  Copyright © 2017年 Facebook. All rights reserved.
//

import Foundation
import MediaPlayer

class VideoContainer: UIView {
  override class var layerClass: AnyClass {
    get {
      return AVPlayerLayer.self
    }
  }
}
