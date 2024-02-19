//
//  CKDVideoCompress.swift
//  CKD
//
//  Created by Chen JmoVxia on 2024/1/26.
//  Copyright © 2024 JmoVxia. All rights reserved.
//

import AVFoundation
import UIKit
import VideoToolbox

extension CKDVideoCompress {
    enum VideoSize {
        case size640x480
        case size960x540
        case size1280x720
        case size1920x1080
        case size3840x2160

        var dimensions: CGSize {
            switch self {
            case .size640x480: CGSize(width: 640, height: 480)
            case .size960x540: CGSize(width: 960, height: 540)
            case .size1280x720: CGSize(width: 1280, height: 720)
            case .size1920x1080: CGSize(width: 1920, height: 1080)
            case .size3840x2160: CGSize(width: 3840, height: 2160)
            }
        }
    }

    enum ExportFileType {
        case mp4
        case mov

        var avFileType: AVFileType {
            switch self {
            case .mov: .mov
            case .mp4: .mp4
            }
        }

        var fileExtension: String {
            switch self {
            case .mov: ".mov"
            case .mp4: ".mp4"
            }
        }
    }

    enum CompressionError: Error {
        case cancelled
        case failedToLoadAsset
        case failedToWriteAsset
        case underlying(Error)
    }
}

extension CKDVideoCompress {
    struct Configuration {
        var videoSize: VideoSize = .size1280x720
        var exportFileType: ExportFileType = .mp4
        var frameDuration: Float = 30
    }
}

class CKDVideoCompress {
    private var config: Configuration

    private var isCancelled = false

    private let audioQueue = DispatchQueue(label: "com.WLPhotoPicker.DispatchQueue.VideoExportTool.Audio", qos: .userInteractive)

    private let videoQueue = DispatchQueue(label: "com.WLPhotoPicker.DispatchQueue.VideoExportTool.Video", qos: .userInteractive)

    private let composition = AVMutableComposition()

    private let videoComposition = AVMutableVideoComposition()

    private let avAsset: AVAsset

    private let inputPath: String

    private let outputPath: String

    init(inputPath: String, outputPath: String, config: Configuration = Configuration()) {
        avAsset = AVAsset(url: URL(fileURLWithPath: inputPath))
        self.inputPath = inputPath
        self.outputPath = outputPath
        self.config = config

        setupTracks()
        updateComposition()
    }
}

private extension CKDVideoCompress {
    func setupTracks() {
        let id = kCMPersistentTrackID_Invalid

        guard let assetVideoTrack = avAsset.tracks(withMediaType: .video).first,
              let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: id)
        else {
            return
        }

        let assetDuration = avAsset.duration
        let timeRange = CMTimeRange(start: .zero, duration: assetDuration)
        var renderSize = assetVideoTrack.naturalSize.applying(assetVideoTrack.preferredTransform)
        renderSize = CGSize(width: abs(renderSize.width), height: abs(renderSize.height))
        let preferredTransform = fixedTransformFrom(transForm: assetVideoTrack.preferredTransform,
                                                    natureSize: assetVideoTrack.naturalSize)

        videoCompositionTrack.preferredTransform = avAsset.preferredTransform
        try? videoCompositionTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)

        let videolayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
        videolayerInstruction.setTransform(preferredTransform, at: .zero)

        let videoCompositionInstrution = AVMutableVideoCompositionInstruction()
        videoCompositionInstrution.timeRange = timeRange
        videoCompositionInstrution.layerInstructions = [videolayerInstruction]

        videoComposition.renderSize = renderSize
        videoComposition.instructions = [videoCompositionInstrution]

        if let assetAudioTrack = avAsset.tracks(withMediaType: .audio).first,
           let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: id)
        {
            try? audioCompositionTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
        }
    }

    func updateComposition() {
        guard let assetVideoTrack = composition.tracks(withMediaType: .video).first else { return }
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(min(max(0, config.frameDuration), assetVideoTrack.nominalFrameRate)))
    }
}

private extension CKDVideoCompress {
    func shouldCompress() -> Bool {
        let videoExportSize = computeVideoExportSize()
        let dimensions = config.videoSize.dimensions
        let nominalFrameRate = composition.tracks(withMediaType: .video).first?.nominalFrameRate ?? config.frameDuration
        return videoExportSize.width * videoExportSize.height > dimensions.width * dimensions.height || nominalFrameRate > config.frameDuration
    }

    func videoWriterConfig() -> [String: Any] {
        func calculateBitRate() -> Float {
            let bitRate = Float(0.1 * videoExportSize.height * videoExportSize.width) * Float(videoComposition.frameDuration.timescale)
            let estimatedDataRate = composition.tracks(withMediaType: .video).first?.estimatedDataRate ?? bitRate
            return min(estimatedDataRate, bitRate)
        }

        let videoExportSize = computeVideoExportSize()
        let bitRate = calculateBitRate()

        let supportHEVC = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
        let codec = supportHEVC ? AVVideoCodecType.hevc : .h264
        let profileLevel = supportHEVC ? kVTProfileLevel_HEVC_Main_AutoLevel as String : AVVideoProfileLevelH264MainAutoLevel

        return [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: videoExportSize.width,
            AVVideoHeightKey: videoExportSize.height,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
            AVVideoCompressionPropertiesKey: [
                AVVideoProfileLevelKey: profileLevel,
                AVVideoAverageBitRateKey: bitRate,
                AVVideoMaxKeyFrameIntervalKey: videoComposition.frameDuration.timescale,
            ],
        ]
    }

    func audioWriterConfig() -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVEncoderBitRatePerChannelKey: 64000,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
        ]
    }

    func computeVideoExportSize() -> CGSize {
        let renderSize = videoComposition.renderSize

        let videoShortSide = min(renderSize.width, renderSize.height)
        let videoLongSide = max(renderSize.width, renderSize.height)
        let videoRatio = videoShortSide / videoLongSide

        let exportSize = config.videoSize.dimensions
        let exportShortSide = min(exportSize.width, exportSize.height)
        let exportLongSide = max(exportSize.width, exportSize.height)
        let exportRatio = exportShortSide / exportLongSide

        let shortSide: CGFloat
        let longSide: CGFloat
        if videoRatio > exportRatio {
            shortSide = min(videoShortSide, exportShortSide)
            longSide = shortSide / videoRatio
        } else {
            longSide = min(videoLongSide, exportLongSide)
            shortSide = longSide * videoRatio
        }
        if renderSize.width > renderSize.height {
            return CGSize(width: longSide, height: shortSide)
        } else {
            return CGSize(width: shortSide, height: longSide)
        }
    }

    func fixedTransformFrom(transForm: CGAffineTransform, natureSize: CGSize) -> CGAffineTransform {
        switch (transForm.a, transForm.b, transForm.c, transForm.d) {
        case (0, 1, -1, 0):
            CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: natureSize.height, ty: 0)
        case (0, -1, 1, 0):
            CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: natureSize.width)
        case (0, 1, 1, 0):
            CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: -natureSize.height, ty: 2 * natureSize.width)
        case (-1, 0, 0, -1):
            CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: natureSize.width, ty: natureSize.height)
        default:
            .identity
        }
    }
}

extension CKDVideoCompress {
    func addWaterMark(image: UIImage?, configuration: (CGSize) -> CGRect) {
        guard let image else { return }
        let renderSize = videoComposition.renderSize

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: renderSize)

        let parentLayer = CALayer()
        parentLayer.backgroundColor = UIColor.clear.cgColor
        parentLayer.frame = videoLayer.bounds
        parentLayer.addSublayer(videoLayer)

        let waterMarkLayer = CALayer()
        var rect = configuration(renderSize)
        rect.origin.y = renderSize.height - rect.maxY
        waterMarkLayer.frame = rect
        waterMarkLayer.contents = image.cgImage
        parentLayer.addSublayer(waterMarkLayer)

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    }

    func addAudio(audioUrl: URL) {
        for track in composition.tracks(withMediaType: .audio) {
            composition.removeTrack(track)
        }
        let audioAsset = AVAsset(url: audioUrl)
        guard let avAssetAudioTrack = audioAsset.tracks(withMediaType: .audio).first else {
            return
        }
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let timeRange = CMTimeRange(start: .zero, duration: avAsset.duration)
        try? audioTrack?.insertTimeRange(timeRange, of: avAssetAudioTrack, at: .zero)
    }

    func exportVideo(progress: ((Double) -> Void)? = nil, completion: @escaping ((Swift.Result<String, CompressionError>) -> Void)) {
        guard shouldCompress() else { return DispatchQueue.main.async { completion(.success(self.inputPath)) } }

        guard let assetReader = try? AVAssetReader(asset: composition) else { return DispatchQueue.main.async { completion(.failure(.failedToLoadAsset)) } }

        if FileManager.default.fileExists(atPath: outputPath) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: outputPath))
        }

        guard let assetWriter = try? AVAssetWriter(outputURL: URL(fileURLWithPath: outputPath), fileType: config.exportFileType.avFileType) else { return DispatchQueue.main.async { completion(.failure(.failedToWriteAsset)) } }
        assetWriter.shouldOptimizeForNetworkUse = true

        let readerVideoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: composition.tracks(withMediaType: .video), videoSettings: nil)
        readerVideoOutput.videoComposition = videoComposition
        readerVideoOutput.alwaysCopiesSampleData = false
        if assetReader.canAdd(readerVideoOutput) {
            assetReader.add(readerVideoOutput)
        }

        let assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoWriterConfig())
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        if assetWriter.canAdd(assetWriterVideoInput) {
            assetWriter.add(assetWriterVideoInput)
        }

        var readerAudioOutput: AVAssetReaderAudioMixOutput?
        var assetWriterAudioInput: AVAssetWriterInput?
        let audioTracks = composition.tracks(withMediaType: .audio)
        if audioTracks.count > 0 {
            readerAudioOutput = AVAssetReaderAudioMixOutput(audioTracks: composition.tracks(withMediaType: .audio), audioSettings: nil)
            readerAudioOutput!.alwaysCopiesSampleData = false
            if assetReader.canAdd(readerAudioOutput!) {
                assetReader.add(readerAudioOutput!)
            }

            assetWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioWriterConfig())
            assetWriterAudioInput!.expectsMediaDataInRealTime = true
            if assetWriter.canAdd(assetWriterAudioInput!) {
                assetWriter.add(assetWriterAudioInput!)
            }
        }

        assetReader.startReading()
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)

        let videoProgressWeight: TimeInterval = 0.5
        let audioProgressWeight: TimeInterval = 0.5

        var videoProgress: TimeInterval = 0
        var audioProgress: TimeInterval = 0

        let dispatchGroup = DispatchGroup()

        let totalVideoSeconds = composition.duration.seconds
        let totalAudioSeconds = audioTracks.count > 0 ? audioTracks[0].timeRange.duration.seconds : 0

        dispatchGroup.enter()
        assetWriterVideoInput.requestMediaDataWhenReady(on: videoQueue) {
            while assetWriterVideoInput.isReadyForMoreMediaData {
                guard let sampleBuffer = readerVideoOutput.copyNextSampleBuffer(), !self.isCancelled else {
                    assetWriterVideoInput.markAsFinished()
                    dispatchGroup.leave()
                    break
                }
                assetWriterVideoInput.append(sampleBuffer)
                let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                videoProgress = timeStamp.seconds / totalVideoSeconds
                DispatchQueue.main.async {
                    progress?((videoProgress * videoProgressWeight) + (audioProgress * audioProgressWeight))
                }
            }
        }

        if let assetWriterAudioInput,
           let readerAudioOutput
        {
            dispatchGroup.enter()
            assetWriterAudioInput.requestMediaDataWhenReady(on: audioQueue) {
                while assetWriterAudioInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = readerAudioOutput.copyNextSampleBuffer(), !self.isCancelled else {
                        assetWriterAudioInput.markAsFinished()
                        dispatchGroup.leave()
                        break
                    }
                    assetWriterAudioInput.append(sampleBuffer)
                    let timeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    audioProgress = timeStamp.seconds / totalAudioSeconds
                    DispatchQueue.main.async {
                        progress?((videoProgress * videoProgressWeight) + (audioProgress * audioProgressWeight))
                    }
                }
            }
        }

        dispatchGroup.notify(queue: .main) {
            assetReader.cancelReading()
            assetWriter.finishWriting {
                DispatchQueue.main.async {
                    if self.isCancelled {
                        completion(.failure(.cancelled))
                    } else if let error = assetReader.error {
                        completion(.failure(.underlying(error)))
                    } else if let error = assetWriter.error {
                        completion(.failure(.underlying(error)))
                    } else {
                        progress?(1)
                        completion(.success(self.outputPath))
                    }
                }
            }
        }
    }

    func cancel() {
        isCancelled = true
    }
}
