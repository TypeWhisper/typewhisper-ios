import UIKit
import SwiftUI
import AVFoundation

class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardHostingView>?
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Report full access status to main app via App Group
        if let defaults = UserDefaults(suiteName: TypeWhisperConstants.appGroupIdentifier) {
            defaults.set(hasFullAccess, forKey: TypeWhisperConstants.SharedDefaults.keyboardHasFullAccess)
            defaults.set(Date().timeIntervalSince1970, forKey: TypeWhisperConstants.SharedDefaults.keyboardLastCheckedAt)
        }

        setupAudioSession()

        let keyboardView = KeyboardHostingView(
            inputViewController: self,
            textDocumentProxy: textDocumentProxy as UITextDocumentProxy
        )

        let hostingController = UIHostingController(rootView: keyboardView)
        hostingController.view.backgroundColor = .clear
        self.hostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        hostingController.didMove(toParent: self)

        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        heightConstraint = view.heightAnchor.constraint(equalToConstant: isPad ? 340 : 260)
        heightConstraint?.priority = .defaultHigh
        heightConstraint?.isActive = true

        updateKeyboardHeight()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateKeyboardHeight()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.updateKeyboardHeight()
        }
    }

    override func textWillChange(_ textInput: UITextInput?) {}
    override func textDidChange(_ textInput: UITextInput?) {}

    private func updateKeyboardHeight() {
        let size = view.bounds.size
        guard size.height > 0, size.width > 0 else { return }

        let metrics = KeyboardMetrics.resolve(for: size)
        if heightConstraint?.constant != metrics.keyboardHeight {
            heightConstraint?.constant = metrics.keyboardHeight
        }
    }

    private func setupAudioSession() {
        let hasFullAccess = self.hasFullAccess

        if !hasFullAccess {
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try audioSession.setActive(true)
        } catch {
            print("[KeyboardVC] Audio session setup failed: \(error)")
        }
    }
}
