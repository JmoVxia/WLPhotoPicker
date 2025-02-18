//
//  VideoCompressViewController.swift
//  WLPhotoPicker_Example
//
//  Created by Mr.Wang on 2022/1/27.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import UIKit
import WLPhotoPicker
import AVKit
import SVProgressHUD

class VideoCompressViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tipLabel = UILabel()
        tipLabel.numberOfLines = 0
        tipLabel.font = UIFont.systemFont(ofSize: 15)
        tipLabel.text = "把视频文件拖到项目中，修改 VideoCompressViewController 中的文件名，再点击“开始压缩”按钮"
        view.addSubview(tipLabel)
        tipLabel.snp.makeConstraints { make in
            make.left.equalTo(20)
            make.top.equalTo(100)
            make.centerX.equalToSuperview()
        }
        
        let button = UIButton()
        button.setTitle("开始压缩", for: .normal)
        button.addTarget(self, action: #selector(beginCompress), for: .touchUpInside)
        view.addSubview(button)
        button.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(tipLabel.snp.bottom).offset(30)
        }
        
        if #available(iOS 13.0, *) {
            view.backgroundColor = UIColor { traitCollection -> UIColor in
                if traitCollection.userInterfaceStyle == .dark {
                    return .black
                } else {
                    return .white
                }
            }
            tipLabel.textColor = UIColor { traitCollection -> UIColor in
                if traitCollection.userInterfaceStyle == .dark {
                    return .white
                } else {
                    return .darkGray
                }
            }
            button.setTitleColor(UIColor { traitCollection -> UIColor in
                if traitCollection.userInterfaceStyle == .dark {
                    return .white
                } else {
                    return .black
                }
            }, for: .normal)
        } else {
            tipLabel.textColor = .darkGray
            view.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
        }
    }
    
    @objc func beginCompress() {
        guard let videoPath = Bundle.main.path(forResource: "video", ofType: "mp4") else {
            return
        }
        
        let outputPath = NSTemporaryDirectory() + "video.mp4"
        if FileManager.default.fileExists(atPath: outputPath) {
            try? FileManager.default.removeItem(atPath: outputPath)
        }
        let manager = CKDVideoCompress(inputPath: videoPath, outputPath: outputPath, config: .init(videoSize: .size960x540, exportFileType: .mp4, frameDuration: 24))
//        manager.compressSize = ._1280x720
//        manager.frameDuration = 24
//        manager.videoExportFileType = .mp4
        if !(TARGET_IPHONE_SIMULATOR == 1 && TARGET_OS_IPHONE == 1) {
            // 模拟器调用添加水印方法会崩溃，有没有大佬知道解决办法
            // https://developer.apple.com/library/archive/samplecode/AVSimpleEditoriOS/Introduction/Intro.html#//apple_ref/doc/uid/DTS40012797
            // 官方demo也会崩溃 = =、
//            manager.addWaterMark(image: UIImage.init(named: "bilibili")) { size in
//                return CGRect(x: size.width * 0.75, y: size.width * 0.05, width: size.width * 0.2, height: size.width * 0.1)
//            }
        }
        let start = Date()

        manager.exportVideo { progress in
//            print("=========\(String(format: "%.2lf%", progress * 100))==========")
            SVProgressHUD.showProgress(Float(progress))
        } completion: { result in
            let end = Date()
            print("==== 耗时 ====\(String(format: "%.2f", end.timeIntervalSince1970 - start.timeIntervalSince1970))s==========")
            result.success { outputURL in
                SVProgressHUD.dismiss()
                print(outputURL)
                let playerItem = AVPlayerItem(asset: AVAsset(url: URL(fileURLWithPath: outputURL)))
                let player = AVPlayer(playerItem: playerItem)
                let controller = AVPlayerViewController()
                controller.player = player
                self.present(controller, animated: true) {
                    player.play()
                }
            }.failure { error in
                SVProgressHUD.showError(withStatus: "压缩失败")
            }
        }

    }
    
}
