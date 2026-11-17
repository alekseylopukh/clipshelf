import Foundation
import Testing
@testable import ShelfUI

struct URLRouteTests {
    @Test(arguments: [
        ("clipsy://open", URLRoute.openShelf),
        ("CLIPSY://Open/", .openShelf),
        ("clipsy://search?q=invoice%20march", .search("invoice march")),
        ("clipsy://search", .search("")),
        ("clipsy://new?text=Hello%2C%20world", .newTextCard("Hello, world")),
        ("clipsy://new", .newTextCard("")),
        ("clipsy://settings", .openSettings)
    ])
    func `parses each route`(string: String, route: URLRoute) throws {
        let url = try #require(URL(string: string))
        #expect(URLRoute(url) == route)
    }

    @Test(arguments: [
        "clipsy://delete",
        "clipsy://",
        "clipsy:open",
        "clipsy://open/extra",
        "https://open",
        "otherapp://search?q=a"
    ])
    func `rejects unknown route`(string: String) throws {
        let url = try #require(URL(string: string))
        #expect(URLRoute(url) == nil)
    }
}
