import Testing
@testable import ShelfUI

struct CardFooterTests {
    @Test(arguments: [
        (host: "www.example.com", expected: "example.com"),
        (host: "example.com", expected: "example.com"),
        (host: "wwwexample.com", expected: "wwwexample.com")
    ])
    func `display host drops a leading www`(host: String, expected: String) {
        #expect(CardFooter.displayHost(host) == expected)
    }
}
