import Testing
@testable import ShelfUI

struct CodeLikeTextTests {
    @Test(arguments: [
        "func greet(_ name: String) -> String {\n    return \"Hello, \\(name)\"\n}",
        "{\n  \"name\": \"Clipsy\",\n  \"version\": 1\n}",
        "<ul>\n  <li>One</li>\n  <li>Two</li>\n</ul>",
        "def greet(name):\n    return name.upper()",
        "let total = price * quantity",
        "import Foundation",
        "SELECT id FROM card WHERE kind = 1;",
        "if (count > 0 && isEnabled) {"
    ])
    func `code is detected`(text: String) {
        #expect(CodeLikeText.isCodeLike(text))
    }

    @Test(arguments: [
        "Remember to pick up the framed print from the gallery on Thursday.",
        "Please check the item(s) before you leave.",
        "let me know",
        "Milk\nEggs\nBread",
        "Dear Anna,\n\nThanks for the photos. See you on Friday!\n\nBest,\nMark",
        "Meeting at 10:30, room 4",
        "",
        "   \n  "
    ])
    func `prose is not code`(text: String) {
        #expect(CodeLikeText.isCodeLike(text) == false)
    }
}
