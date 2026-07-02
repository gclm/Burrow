//
//  RemovableVolumeGuardTests.swift
//  BurrowTests
//

import XCTest
@testable import Burrow

final class RemovableVolumeGuardTests: XCTestCase {
    func testUnpluggedVolume_isNotBroken() {
        XCTAssertEqual(RemovableVolumeGuard.classify(missingPath: "/Volumes/MyDrive/App.app/Contents/MacOS/App",
                                                     mountedVolumes: []), .onUnpluggedVolume)
        XCTAssertEqual(RemovableVolumeGuard.classify(missingPath: "/Volumes/Backup/x",
                                                     mountedVolumes: ["/Volumes/Other"]), .onUnpluggedVolume)
    }

    func testMountedButMissing_isBroken() {
        XCTAssertEqual(RemovableVolumeGuard.classify(missingPath: "/Volumes/MyDrive/App.app",
                                                     mountedVolumes: ["/Volumes/MyDrive"]), .broken)
    }

    func testInternalPath_isBroken() {
        XCTAssertEqual(RemovableVolumeGuard.classify(missingPath: "/Applications/Foo.app/Contents/MacOS/Foo",
                                                     mountedVolumes: []), .broken)
        XCTAssertEqual(RemovableVolumeGuard.classify(missingPath: "/Volumes",
                                                     mountedVolumes: []), .broken)
    }
}
