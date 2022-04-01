import UIKit
import BanubaSdk
import AVKit

class PhotoAndVideoViewController: UIViewController {

    @IBOutlet weak var effectView: EffectPlayerView!
    @IBOutlet weak var recordButton: UIButton!
    
    private var sdkManager = BanubaSdkManager()
    private let config = EffectPlayerConfiguration(renderMode: .video)
    var isRecording = false
    
    var lastVideoRecordedURL: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        effectView.layoutIfNeeded()
        sdkManager.setup(configuration: config)
        setUpRenderSize()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(pushPhotoButton))
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(pushRecordButton))
        
        recordButton.addGestureRecognizer(tapGesture)
        recordButton.addGestureRecognizer(longPressGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sdkManager.input.startCamera()
        _ = sdkManager.loadEffect("TrollGrandma", synchronous: true)
        sdkManager.startEffectPlayer()
    }
    
    deinit {
        sdkManager.destroyEffectPlayer()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        sdkManager.stopEffectPlayer()
        sdkManager.removeRenderTarget()
        coordinator.animateAlongsideTransition(in: effectView, animation: { (UIViewControllerTransitionCoordinatorContext) in
            self.sdkManager.autoRotationEnabled = true
            self.setUpRenderSize()
        }, completion: nil)
    }
    
    private func setUpRenderTarget() {
        sdkManager.setRenderTarget(view: effectView, playerConfiguration: nil)
        sdkManager.startEffectPlayer()
    }
    
    private func setUpRenderSize() {
        switch UIApplication.shared.statusBarOrientation {
        case .portrait:
            config.orientation = .deg90
            config.renderSize = CGSize(width: 720, height: 1280)
            sdkManager.autoRotationEnabled = false
            setUpRenderTarget()
        case .portraitUpsideDown:
            config.orientation = .deg270
            config.renderSize = CGSize(width: 720, height: 1280)
            setUpRenderTarget()
        case .landscapeLeft:
            config.orientation = .deg180
            config.renderSize = CGSize(width: 1280, height: 720)
            setUpRenderTarget()
        case .landscapeRight:
            config.orientation = .deg0
            config.renderSize = CGSize(width: 1280, height: 720)
            setUpRenderTarget()
        default:
            setUpRenderTarget()
        }
    }
    
    @IBAction func closeCamera(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    @objc func pushRecordButton(_ sender: UIGestureRecognizer) {
        switch sender.state {
        case .began:
            self.isRecording = true
            self.recordButton.setImage(UIImage(named: "stop_video"), for: .normal)
            self.recordVideo(self.isRecording)
        case .ended:
            self.isRecording = false
            self.recordButton.setImage(UIImage(named: "shutter_video"), for: .normal)
            sdkManager.output?.stopVideoCapturing(cancel: false)
        default:
            break
        }
    }
    
    @objc func pushPhotoButton(_ sender: UIGestureRecognizer) {
        makeCameraPhoto()
    }
    
    private func saveVideoToGallery(fileURL: String) {
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileURL) {
            UISaveVideoAtPathToSavedPhotosAlbum(fileURL, nil, nil, nil)
        }
    }
    
    func recordVideo(_ shouldRecord: Bool){
        let hasSpace =  sdkManager.output?.hasDiskCapacityForRecording() ?? true
        if shouldRecord && hasSpace {
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("video.mp4")
            
            sdkManager.input.startAudioCapturing()
            sdkManager.output?.startVideoCapturing(fileURL:fileURL) { (success, error) in
                print("Done Writing: \(success)")
                if let _error = error {
                    print(_error)
                }
                self.sdkManager.input.stopAudioCapturing()
                self.saveVideoToGallery(fileURL: fileURL.relativePath)
                self.lastVideoRecordedURL = fileURL
                
                DispatchQueue.main.async {
                    self.presentVideo()
                }
            }
        } else {
            sdkManager.output?.stopVideoCapturing(cancel: false)
        }
    }
    
    func makeCameraPhoto() {
        sdkManager.makeCameraPhoto(cameraSettings: .init(useStabilization: false, flashMode: .off), completion: { image in
            DispatchQueue.main.sync {
                self.presentImage(image!)
            }
        })
    }
    
    private func presentVideo() {
        guard let lastVideoRecordedURL = lastVideoRecordedURL else {
            return
        }
        let player = AVPlayer(url: lastVideoRecordedURL)
        let vc = AVPlayerViewController()
        vc.player = player

        present(vc, animated: true) {
            vc.player?.play()
        }
    }
    
    private func presentImage(_ image: UIImage) {
        let imageViewController = PresentImageViewController()
        imageViewController.setImage(to: image)
        self.present(imageViewController, animated: true, completion: nil)
    }
}

class PresentImageViewController: UIViewController {
    
    private let imageView = UIImageView()
    
    override func viewDidLoad() {
        view.addSubview(imageView)
        
        imageView.frame = view.frame
    }
    
    func setImage(to image: UIImage) {
        imageView.image = image
    }
}

