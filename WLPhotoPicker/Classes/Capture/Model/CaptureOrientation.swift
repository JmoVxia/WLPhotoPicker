//
//  CaptureOrientation.swift
//  WLPhotoPicker
//
//  Created by Mr.Wang on 2022/1/1.
//

import CoreMotion
import AVFoundation

protocol CaptureOrientationManagerDelegate: AnyObject {
    func captureOrientation(_ deviceOrientation: CaptureOrientationManager, didUpdate orientation: CaptureOrientation)
}

class CaptureOrientationManager: NSObject {

    weak var delegate: CaptureOrientationManagerDelegate?
    
    let motionManager = CMMotionManager()
    
    override init() {
        super.init()
        motionManager.deviceMotionUpdateInterval = 0.5
    }
    
    func startUpdates() {
        if motionManager.isDeviceMotionAvailable,
           let queue = OperationQueue.current {
            motionManager.startDeviceMotionUpdates(to: queue) { (motion, _) in
                self.deviceMotion(motion)
            }
        }
    }
    
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    func deviceMotion(_ motion: CMDeviceMotion?) {
        guard let motion = motion else {
            delegate?.captureOrientation(self, didUpdate: .up)
            return
        }
        
        let x = motion.gravity.x
        let y = motion.gravity.y
        
        let angle = atan2(y, x)
        let threshold: Double = .pi / 4 // 45 degrees
        
        if abs(angle) < threshold {
            if x > 0 {
                delegate?.captureOrientation(self, didUpdate: .right)
            } else {
                delegate?.captureOrientation(self, didUpdate: .left)
            }
        } else {
            if y > 0 {
                delegate?.captureOrientation(self, didUpdate: .down)
            } else {
                delegate?.captureOrientation(self, didUpdate: .up)
            }
        }
    }
    
}

enum CaptureOrientation {
    case up
    case left
    case down
    case right
}

extension CaptureOrientation {
    
    var captureVideoOrientation: AVCaptureVideoOrientation {
        switch self {
        case .up:
            return .portrait
        case .left:
            return .landscapeRight
        case .down:
            return .portraitUpsideDown
        case .right:
            return .landscapeLeft
        }
    }
    
    var imageOrientation: UIImage.Orientation {
        switch self {
        case .up:
            return .up
        case .left:
            return .left
        case .down:
            return .down
        case .right:
            return .right
        }
    }
    
}
