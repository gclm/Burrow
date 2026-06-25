import XCTest
@testable import Burrow

final class LoginItemsReaderTests: XCTestCase {
    // Trimmed real `sfltool dumpbtm` output.
    private let sample = """
     #1:
                     UUID: 903AE041-3324-4304-B0DF-4BAB525E0E31
                     Name: (null)
           Developer Name: (null)
                     Type: developer (0x20)
              Disposition: [disabled, allowed, not notified] (0x2)
               Identifier: Unknown Developer

     #2:
                     UUID: 5A133E95-92FB-42BA-859C-2A0675FC20AF
                     Name: studio-route-guard.sh
           Developer Name: (null)
                     Type: legacy daemon (0x10010)
              Disposition: [enabled, allowed, notified] (0xb)
               Identifier: 16.com.henry.studio-route-guard
          Executable Path: /usr/local/bin/studio-route-guard.sh

     #3:
                     UUID: F499CCD9-B4EF-4401-BF89-FC10AE47C520
                     Name: Docker
           Developer Name: Docker
                     Type: developer (0x20)
              Disposition: [enabled, allowed, notified] (0xb)
               Identifier: com.docker.docker
    """

    func testParsesTypeAndEnabled() {
        let items = LoginItemsReader.parse(sample)
        let srg = items.first { $0.identifier == "16.com.henry.studio-route-guard" }
        XCTAssertEqual(srg?.name, "studio-route-guard.sh")
        XCTAssertEqual(srg?.type, "legacy daemon")
        XCTAssertEqual(srg?.enabled, true)
        let docker = items.first { $0.name == "Docker" }
        XCTAssertEqual(docker?.developer, "Docker")
        XCTAssertEqual(docker?.enabled, true)
    }

    func testDisabledRecord() {
        let unknown = LoginItemsReader.parse(sample).first { $0.identifier == "Unknown Developer" }
        XCTAssertEqual(unknown?.enabled, false)
    }
}
