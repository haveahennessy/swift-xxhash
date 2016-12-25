//
//  swift_xxhashTests.swift
//  swift-xxhashTests
//
//  Created by Matt Isaacs.
//

import XCTest
@testable import xxHash

class swift_xxhashTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testStreamingHashEmpty() {
        let state = XXHash(seed: 0)
        let hash  = state.digest()
        XCTAssertEqual(hash, 0xef46db3751d8e999)
        print(String(format: "0x%lx", hash))
    }

    func testStreamingHashSingle() {
        var state = XXHash(seed: 0)
        state.update(buffer: [42])
        let hash = state.digest()
        
        print(String(format: "0x%lx", hash))
        XCTAssertEqual(hash, 0xa9edecebeb03ae4)
    }

    func testStreamingHashLargerBuffer() {
        var state = XXHash(seed: 0)
        let buffer = Array<UInt8>(0..<100)

        state.update(buffer: buffer)

        let hash  = state.digest()
        print(String(format: "0x%lx", hash))
        XCTAssertEqual(hash, 0x6ac1e58032166597)
    }

    func testPerformanceExample() {
        self.measure {
        }
    }
    
}
