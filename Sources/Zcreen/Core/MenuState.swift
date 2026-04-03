import Combine

final class MenuState: ObservableObject {
    @Published var autoApplyOnScreenChange: Bool
    @Published var autoApplyOnAppLaunch: Bool
    @Published var snapBarEnabled: Bool

    private let settingsStore: MenuSettingsStore
    private var cancellables = Set<AnyCancellable>()
    private var hasConnectedSnapBar = false
    private var isSyncingSnapBar = false

    init(settingsStore: MenuSettingsStore = MenuSettingsStore()) {
        self.settingsStore = settingsStore
        self.autoApplyOnScreenChange = settingsStore.bool(for: .autoApplyOnScreenChange, default: true)
        self.autoApplyOnAppLaunch = settingsStore.bool(for: .autoApplyOnAppLaunch, default: true)
        self.snapBarEnabled = settingsStore.bool(for: .snapBarEnabled, default: true)

        bindPersistence()
    }

    func connect(snapBarController: SnapBarController) {
        guard !hasConnectedSnapBar else { return }
        hasConnectedSnapBar = true

        if snapBarController.isEnabled != snapBarEnabled {
            snapBarController.isEnabled = snapBarEnabled
        }

        $snapBarEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self, weak snapBarController] value in
                guard let self, let snapBarController else { return }
                guard !self.isSyncingSnapBar else { return }

                self.isSyncingSnapBar = true
                defer { self.isSyncingSnapBar = false }
                snapBarController.isEnabled = value
            }
            .store(in: &cancellables)

        snapBarController.$isEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                guard !self.isSyncingSnapBar else { return }

                self.isSyncingSnapBar = true
                defer { self.isSyncingSnapBar = false }
                self.snapBarEnabled = value
            }
            .store(in: &cancellables)
    }

    private func bindPersistence() {
        $autoApplyOnScreenChange
            .dropFirst()
            .sink { [settingsStore] value in
                settingsStore.set(value, for: .autoApplyOnScreenChange)
            }
            .store(in: &cancellables)

        $autoApplyOnAppLaunch
            .dropFirst()
            .sink { [settingsStore] value in
                settingsStore.set(value, for: .autoApplyOnAppLaunch)
            }
            .store(in: &cancellables)

        $snapBarEnabled
            .dropFirst()
            .sink { [settingsStore] value in
                settingsStore.set(value, for: .snapBarEnabled)
            }
            .store(in: &cancellables)
    }
}
