import Combine
import Foundation

@MainActor
final class PrivacyController: ObservableObject {
    @Published private(set) var isMasked: Bool
    @Published private(set) var isWindowHidden = false

    private let preferences: WindowPreferences
    private var revealTask: Task<Void, Never>?

    init(preferences: WindowPreferences = .shared) {
        self.preferences = preferences
        self.isMasked = preferences.maskAmountsByDefault
    }

    deinit {
        revealTask?.cancel()
    }

    func toggleMask() {
        if isMasked {
            revealTemporarily()
        } else {
            mask()
        }
    }

    func revealTemporarily() {
        revealTask?.cancel()
        isMasked = false
        let seconds = max(1, preferences.autoHideSeconds)
        guard preferences.autoHideSeconds > 0 else { return }
        revealTask = Task { [weak self] in
            let nanoseconds = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.mask()
            }
        }
    }

    func mask() {
        revealTask?.cancel()
        revealTask = nil
        isMasked = true
    }

    func enterBossMode() {
        mask()
        isWindowHidden = true
    }

    func leaveBossMode() {
        mask()
        isWindowHidden = false
    }

    func toggleBossMode() -> Bool {
        if isWindowHidden {
            leaveBossMode()
        } else {
            enterBossMode()
        }
        return isWindowHidden
    }

    func applicationBecameInactive() {
        guard preferences.maskOnAppSwitch else { return }
        mask()
    }
}
