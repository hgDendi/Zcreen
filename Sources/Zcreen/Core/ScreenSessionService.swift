final class ScreenSessionService {
    struct ScreenChangeContext {
        let oldProfileKey: String
        let newProfileKey: String
        let newProfileLabel: String
    }

    let screenDetector: ScreenDetector

    private(set) var previousProfileKey: String

    init(screenDetector: ScreenDetector) {
        self.screenDetector = screenDetector
        self.previousProfileKey = screenDetector.profileKey
    }

    var currentProfileKey: String { screenDetector.profileKey }
    var currentProfileLabel: String { screenDetector.profileLabel }
    var currentScreens: [ScreenInfo] { screenDetector.screens }
    var screenCount: Int { screenDetector.screenCount }

    func beginScreenChange(to newProfileKey: String) -> ScreenChangeContext {
        let context = ScreenChangeContext(
            oldProfileKey: previousProfileKey,
            newProfileKey: newProfileKey,
            newProfileLabel: screenDetector.profileLabel
        )
        previousProfileKey = newProfileKey
        return context
    }
}
