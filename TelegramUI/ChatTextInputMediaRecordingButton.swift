import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit

import LegacyComponents

private let offsetThreshold: CGFloat = 10.0
private let dismissOffsetThreshold: CGFloat = 70.0

enum ChatTextInputMediaRecordingButtonMode: Int32 {
    case audio = 0
    case video = 1
}

private final class ChatTextInputMediaRecordingButtonPresenterContainer: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for subview in self.subviews {
            if let result = subview.hitTest(point.offsetBy(dx: -subview.frame.minX, dy: -subview.frame.minY), with: event) {
                return result
            }
        }
        return super.hitTest(point, with: event)
    }
}

private final class ChatTextInputMediaRecordingButtonPresenterController: ViewController {
    override func loadDisplayNode() {
        self.displayNode = ChatTextInputMediaRecordingButtonPresenterControllerNode()
    }
}

private final class ChatTextInputMediaRecordingButtonPresenterControllerNode: ViewControllerTracingNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
}

private final class ChatTextInputMediaRecordingButtonPresenter : NSObject, TGModernConversationInputMicButtonPresentation {
    private let account: Account?
    private let presentController: (ViewController) -> Void
    private let container: ChatTextInputMediaRecordingButtonPresenterContainer
    private var presentationController: ViewController?
    
    init(account: Account, presentController: @escaping (ViewController) -> Void) {
        self.account = account
        self.presentController = presentController
        self.container = ChatTextInputMediaRecordingButtonPresenterContainer()
    }
    
    deinit {
        self.container.removeFromSuperview()
        if let presentationController = self.presentationController {
            presentationController.presentingViewController?.dismiss(animated: false, completion: {})
            self.presentationController = nil
        }
    }
    
    func view() -> UIView! {
        return self.container
    }
    
    func setUserInteractionEnabled(_ enabled: Bool) {
        self.container.isUserInteractionEnabled = enabled
    }
    
    func present() {
        if let keyboardWindow = LegacyComponentsGlobals.provider().applicationKeyboardWindow(), !keyboardWindow.isHidden {
            keyboardWindow.addSubview(self.container)
        } else {
            var presentNow = false
            if self.presentationController == nil {
                let presentationController = ChatTextInputMediaRecordingButtonPresenterController(navigationBarTheme: nil)
                presentationController.statusBar.statusBarStyle = .Ignore
                self.presentationController = presentationController
                presentNow = true
            }
            
            self.presentationController?.displayNode.view.addSubview(self.container)
            if let presentationController = self.presentationController, presentNow {
                self.presentController(presentationController)
            }
        }
    }
    
    func dismiss() {
        self.container.removeFromSuperview()
        if let presentationController = self.presentationController {
            presentationController.presentingViewController?.dismiss(animated: false, completion: {})
            self.presentationController = nil
        }
    }
}

final class ChatTextInputMediaRecordingButton: TGModernConversationInputMicButton, TGModernConversationInputMicButtonDelegate {
    private var theme: PresentationTheme
    
    var mode: ChatTextInputMediaRecordingButtonMode = .audio
    var account: Account?
    let presentController: (ViewController) -> Void
    var beginRecording: () -> Void = { }
    var endRecording: (Bool) -> Void = { _ in }
    var stopRecording: () -> Void = { _ in }
    var offsetRecordingControls: () -> Void = { }
    var switchMode: () -> Void = { }
    var updateLocked: (Bool) -> Void = { _ in }
    
    private var modeTimeoutTimer: SwiftSignalKit.Timer?
    
    private let innerIconView: UIImageView
    
    private var recordingOverlay: ChatTextInputAudioRecordingOverlay?
    private var startTouchLocation: CGPoint?
    private(set) var controlsOffset: CGFloat = 0.0
    
    private var micLevelDisposable: MetaDisposable?
    
    var audioRecorder: ManagedAudioRecorder? {
        didSet {
            if self.audioRecorder !== oldValue {
                if self.micLevelDisposable == nil {
                    micLevelDisposable = MetaDisposable()
                }
                if let audioRecorder = self.audioRecorder {
                    self.micLevelDisposable?.set(audioRecorder.micLevel.start(next: { [weak self] level in
                        Queue.mainQueue().async {
                            //self?.recordingOverlay?.addImmediateMicLevel(CGFloat(level))
                            self?.addMicLevel(CGFloat(level))
                        }
                    }))
                } else if self.videoRecordingStatus == nil {
                    self.micLevelDisposable?.set(nil)
                }
                
                self.hasRecorder = self.audioRecorder != nil || self.videoRecordingStatus != nil
            }
        }
    }
    
    var videoRecordingStatus: InstantVideoControllerRecordingStatus? {
        didSet {
            if self.videoRecordingStatus !== oldValue {
                if self.micLevelDisposable == nil {
                    micLevelDisposable = MetaDisposable()
                }
                
                if let videoRecordingStatus = self.videoRecordingStatus {
                    self.micLevelDisposable?.set(videoRecordingStatus.micLevel.start(next: { [weak self] level in
                        Queue.mainQueue().async {
                            //self?.recordingOverlay?.addImmediateMicLevel(CGFloat(level))
                            self?.addMicLevel(CGFloat(level))
                        }
                    }))
                } else if self.audioRecorder == nil {
                    self.micLevelDisposable?.set(nil)
                }
                
                self.hasRecorder = self.audioRecorder != nil || self.videoRecordingStatus != nil
            }
        }
    }
    
    private var hasRecorder: Bool = false {
        didSet {
            if self.hasRecorder != oldValue {
                if self.hasRecorder {
                    self.animateIn()
                } else {
                    self.animateOut()
                }
            }
        }
    }
    
    init(theme: PresentationTheme, presentController: @escaping (ViewController) -> Void) {
        self.theme = theme
        self.innerIconView = UIImageView()
        self.presentController = presentController
        
        super.init(frame: CGRect())
        
        self.insertSubview(self.innerIconView, at: 0)
        
        self.isExclusiveTouch = true
        self.adjustsImageWhenHighlighted = false
        self.adjustsImageWhenDisabled = false
        self.disablesInteractiveTransitionGestureRecognizer = true
        
        self.updateMode(mode: self.mode, animated: false, force: true)
        
        self.delegate = self
        
        self.centerOffset = CGPoint(x: 0.0, y: -1.0 + UIScreenPixel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateMode(mode: ChatTextInputMediaRecordingButtonMode, animated: Bool) {
        self.updateMode(mode: mode, animated: animated, force: false)
    }
        
    private func updateMode(mode: ChatTextInputMediaRecordingButtonMode, animated: Bool, force: Bool) {
        if mode != self.mode || force {
            self.mode = mode
            
            if animated {
                let previousView = UIImageView(image: self.innerIconView.image)
                previousView.frame = self.innerIconView.frame
                self.addSubview(previousView)
                previousView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
                previousView.layer.animateScale(from: 1.0, to: 0.3, duration: 0.15, removeOnCompletion: false, completion: { [weak previousView] _ in
                    previousView?.removeFromSuperview()
                })
            }
            
            switch self.mode {
                case .audio:
                    self.icon = PresentationResourcesChat.chatInputPanelVoiceActiveButtonImage(self.theme)
                    self.innerIconView.image = PresentationResourcesChat.chatInputPanelVoiceButtonImage(self.theme)
                case .video:
                    self.icon = PresentationResourcesChat.chatInputPanelVideoActiveButtonImage(self.theme)
                    self.innerIconView.image = PresentationResourcesChat.chatInputPanelVideoButtonImage(self.theme)
            }
            if let image = self.innerIconView.image {
                let size = self.bounds.size
                let iconSize = image.size
                self.innerIconView.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
            }
            
            if animated {
                self.innerIconView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15, removeOnCompletion: false)
                self.innerIconView.layer.animateSpring(from: 0.4 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
            }
        }
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.theme = theme
        
        switch self.mode {
            case .audio:
                self.icon = PresentationResourcesChat.chatInputPanelVoiceActiveButtonImage(self.theme)
                self.innerIconView.image = PresentationResourcesChat.chatInputPanelVoiceButtonImage(self.theme)
            case .video:
                self.icon = PresentationResourcesChat.chatInputPanelVideoActiveButtonImage(self.theme)
                self.innerIconView.image = PresentationResourcesChat.chatInputPanelVideoButtonImage(self.theme)
        }
    }
    
    deinit {
        if let micLevelDisposable = self.micLevelDisposable {
            micLevelDisposable.dispose()
        }
        if let recordingOverlay = self.recordingOverlay {
            recordingOverlay.dismiss()
        }
    }
    
    func cancelRecording() {
        self.isEnabled = false
        self.isEnabled = true
    }
    
    /*override func beginTracking(_ touch: UITouch, with touchEvent: UIEvent?) -> Bool {
        if super.beginTracking(touch, with: touchEvent) {
            self.startTouchLocation = touch.location(in: self)
            
            self.controlsOffset = 0.0
            self.beginRecording()
            let recordingOverlay: ChatTextInputAudioRecordingOverlay
            if let currentRecordingOverlay = self.recordingOverlay {
                recordingOverlay = currentRecordingOverlay
            } else {
                recordingOverlay = ChatTextInputAudioRecordingOverlay(anchorView: self)
                self.recordingOverlay = recordingOverlay
            }
            if let account = self.account, let applicationContext = account.applicationContext as? TelegramApplicationContext, let topWindow = applicationContext.applicationBindings.getTopWindow() {
                recordingOverlay.present(in: topWindow)
            }
            return true
        } else {
            return false
        }
    }
    
    override func endTracking(_ touch: UITouch?, with touchEvent: UIEvent?) {
        super.endTracking(touch, with: touchEvent)
        
        self.endRecording(self.controlsOffset < 40.0)
        self.dismissRecordingOverlay()
    }
    
    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        
        self.endRecording(false)
        self.dismissRecordingOverlay()
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        if super.continueTracking(touch, with: event) {
            if let startTouchLocation = self.startTouchLocation {
                let horiontalOffset = startTouchLocation.x - touch.location(in: self).x
                let controlsOffset = max(0.0, horiontalOffset - offsetThreshold)
                if !controlsOffset.isEqual(to: self.controlsOffset) {
                    self.recordingOverlay?.dismissFactor = 1.0 - controlsOffset / dismissOffsetThreshold
                    self.controlsOffset = controlsOffset
                    self.offsetRecordingControls()
                }
            }
            return true
        } else {
            return false
        }
    }
    
    private func dismissRecordingOverlay() {
        if let recordingOverlay = self.recordingOverlay {
            self.recordingOverlay = nil
            recordingOverlay.dismiss()
        }
    }*/
    
    func micButtonInteractionBegan() {
        self.modeTimeoutTimer?.invalidate()
        let modeTimeoutTimer = SwiftSignalKit.Timer(timeout: 0.1, repeat: false, completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.modeTimeoutTimer = nil
                strongSelf.beginRecording()
            }
        }, queue: Queue.mainQueue())
        self.modeTimeoutTimer = modeTimeoutTimer
        modeTimeoutTimer.start()
    }
    
    func micButtonInteractionCancelled(_ velocity: CGPoint) {
        self.modeTimeoutTimer?.invalidate()
        self.endRecording(false)
    }
    
    func micButtonInteractionCompleted(_ velocity: CGPoint) {
        if let modeTimeoutTimer = self.modeTimeoutTimer {
            modeTimeoutTimer.invalidate()
            self.modeTimeoutTimer = nil
            self.switchMode()
        }
        self.endRecording(true)
    }
    
    func micButtonInteractionUpdate(_ offset: CGPoint) {
        self.controlsOffset = offset.x
        self.offsetRecordingControls()
    }
    
    func micButtonInteractionLocked() {
        self.updateLocked(true)
    }
    
    func micButtonInteractionRequestedLockedAction() {
    }
    
    func micButtonInteractionStopped() {
        self.stopRecording()
    }
    
    func micButtonShouldLock() -> Bool {
        return true
    }
    
    func micButtonPresenter() -> TGModernConversationInputMicButtonPresentation! {
        return ChatTextInputMediaRecordingButtonPresenter(account: self.account!, presentController: self.presentController)
    }
    
    private var previousSize = CGSize()
    func layoutItems() {
        let size = self.bounds.size
        if size != self.previousSize {
            self.previousSize = size
            let iconSize = self.innerIconView.bounds.size
            self.innerIconView.frame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
        }
    }
}