public struct RuntimeLanguageState: Equatable, Sendable {
    public private(set) var language: CodexDisplayLanguage
    public private(set) var source: CodexLanguageSource?

    public init(initial: CodexDisplayLanguage = .english) {
        language = initial
        source = nil
    }

    @discardableResult
    public mutating func apply(_ resolved: CodexResolvedLanguage?) -> Bool {
        guard let resolved else {
            return false
        }
        let languageChanged = language != resolved.language
        language = resolved.language
        source = resolved.source
        return languageChanged
    }
}
