import XCTest
@testable import DockStudio

final class RecentDocumentAccessTests: XCTestCase {
    func testRequestsDocumentsForApplicationAndOpensTheSelectedDocumentID() {
        let provider = FakeRecentDocumentProvider()
        let access = RecentDocumentAccess(provider: provider)
        let app = DockItem(name: "Editor", kind: .application, target: "file:///Applications/Editor.app")
        provider.documents = [RecentDocument(id: "file:///tmp/notes.txt", title: "notes.txt")]

        XCTAssertEqual(access.documents(for: app), provider.documents)
        XCTAssertTrue(access.open(documentID: "file:///tmp/notes.txt", for: app))
        XCTAssertEqual(provider.requestedApplicationPaths, ["/Applications/Editor.app", "/Applications/Editor.app"])
        XCTAssertEqual(provider.openedIDs, ["file:///tmp/notes.txt"])
    }

    func testDoesNotRequestOrOpenDocumentsForNonApplications() {
        let provider = FakeRecentDocumentProvider()
        let access = RecentDocumentAccess(provider: provider)
        let folder = DockItem(name: "Folder", kind: .folder, target: "file:///tmp/")

        XCTAssertTrue(access.documents(for: folder).isEmpty)
        XCTAssertFalse(access.open(documentID: "file:///tmp/notes.txt", for: folder))
        XCTAssertTrue(provider.requestedApplicationPaths.isEmpty)
        XCTAssertTrue(provider.openedIDs.isEmpty)
    }

    private final class FakeRecentDocumentProvider: RecentDocumentProviding {
        var documents: [RecentDocument] = []
        private(set) var requestedApplicationPaths: [String] = []
        private(set) var openedIDs: [String] = []

        func documents(for applicationURL: URL) -> [RecentDocument] {
            requestedApplicationPaths.append(applicationURL.path)
            return documents
        }

        func open(documentID: String, for applicationURL: URL) -> Bool {
            requestedApplicationPaths.append(applicationURL.path)
            openedIDs.append(documentID)
            return true
        }
    }
}
