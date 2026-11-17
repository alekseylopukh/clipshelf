import Foundation
import Store

extension ShelfModel {
    public func observeApps() async {
        do {
            for try await apps in observeAppList() {
                receiveApps(apps)
            }
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("app observation failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func updateSuggestions() {
        guard let word = suggestionWord.map({ String(query[$0]) }) else {
            suggestions = []
            highlightedSuggestion = nil
            return
        }
        let candidates = SearchToken.kinds.map(SearchToken.kind)
            + SearchToken.dateRanges.map(SearchToken.date)
            + apps.map(SearchToken.app)
            + boards.map { SearchToken.board(id: $0.id) }
        suggestions = Array(
            candidates
                .lazy
                .filter { !self.tokens.contains($0) && Self.name(self.title(of: $0), startsWith: word) }
                .prefix(Self.suggestionLimit)
        )
        if let highlightedSuggestion, !suggestions.contains(highlightedSuggestion) {
            self.highlightedSuggestion = nil
        }
    }

    func title(of token: SearchToken) -> String {
        switch token {
        case let .kind(kind): kind.name
        case let .app(app): app.name
        case let .date(range): range.name
        case let .board(id): boards.first { $0.id == id }?.name ?? ""
        }
    }

    func addToken(_ token: SearchToken) {
        var newTokens = tokens.filter { $0.category != token.category }
        newTokens.append(token)
        tokens = newTokens
    }

    func removeToken(_ token: SearchToken) {
        tokens.removeAll { $0 == token }
    }

    func toggleToken(_ token: SearchToken) {
        if tokens.contains(token) {
            removeToken(token)
        } else {
            addToken(token)
        }
    }

    func removeLastToken() -> Bool {
        guard query.isEmpty, !tokens.isEmpty else { return false }
        tokens.removeLast()
        return true
    }

    func acceptSuggestion(_ token: SearchToken) {
        if let word = suggestionWord {
            query.removeSubrange(word)
        }
        addToken(token)
    }

    func acceptHighlightedSuggestion() -> Bool {
        guard let highlightedSuggestion else { return false }
        acceptSuggestion(highlightedSuggestion)
        return true
    }

    func moveSuggestionHighlight(_ direction: Direction) -> Bool {
        guard !suggestions.isEmpty else { return false }
        let current = highlightedSuggestion.flatMap(suggestions.firstIndex(of:))
        switch (direction, current) {
        case (.next, nil):
            highlightedSuggestion = suggestions[0]
        case let (.next, index?):
            highlightedSuggestion = suggestions[min(index + 1, suggestions.count - 1)]
        case (.previous, nil), (.previous, 0):
            highlightedSuggestion = nil
        case let (.previous, index?):
            highlightedSuggestion = suggestions[index - 1]
        }
        return true
    }

    func boardsDidChange() {
        tokens.removeAll { token in
            guard case let .board(id) = token else { return false }
            return !boards.contains { $0.id == id }
        }
        updateSuggestions()
    }

    func receiveApps(_ newApps: [SourceApp]) {
        apps = newApps
        updateSuggestions()
    }

    private var suggestionWord: Range<String.Index>? {
        let start = query.lastIndex(where: \.isWhitespace).map(query.index(after:)) ?? query.startIndex
        guard query.distance(from: start, to: query.endIndex) >= Self.suggestionMinimumLength else { return nil }
        return start ..< query.endIndex
    }

    private static func name(_ name: String, startsWith word: String) -> Bool {
        var start = name.startIndex
        while start < name.endIndex {
            if name.range(
                of: word,
                options: [.anchored, .caseInsensitive, .diacriticInsensitive],
                range: start ..< name.endIndex
            ) != nil {
                return true
            }
            guard let space = name[start...].firstIndex(where: \.isWhitespace) else { return false }
            start = name.index(after: space)
        }
        return false
    }

    private static let suggestionMinimumLength = 2
    private static let suggestionLimit = 6
}
