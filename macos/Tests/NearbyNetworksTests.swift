import XCTest
@testable import Burrow

final class NearbyNetworksTests: XCTestCase {
    func testSortByStrength() {
        let nets = [
            NearbyNetworks.Net(ssid: "a", rssi: -80, channel: 1, security: "WPA2"),
            NearbyNetworks.Net(ssid: "b", rssi: -40, channel: 6, security: "WPA3"),
            NearbyNetworks.Net(ssid: "c", rssi: -60, channel: 6, security: "WPA2"),
        ]
        XCTAssertEqual(NearbyNetworks.byStrength(nets).map(\.ssid), ["b", "c", "a"])
    }

    func testCongestedChannels() {
        let nets = [
            NearbyNetworks.Net(ssid: "a", rssi: -40, channel: 6, security: ""),
            NearbyNetworks.Net(ssid: "b", rssi: -50, channel: 6, security: ""),
            NearbyNetworks.Net(ssid: "c", rssi: -60, channel: 6, security: ""),
            NearbyNetworks.Net(ssid: "d", rssi: -40, channel: 1, security: ""),
        ]
        XCTAssertEqual(NearbyNetworks.congestedChannels(nets, threshold: 2), [6])
    }
}
