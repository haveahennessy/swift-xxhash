//
//  Hash.swift
//  swift-xxhash
//
//  Created by Matt Isaacs.
//  Copyright © 2016 haveahennessy. All rights reserved.
//

import Foundation

private struct XXPrimes {
    static let prime1:UInt64 = 11400714785074694791
    static let prime2:UInt64 = 14029467366897019727
    static let prime3:UInt64 = 1609587929392839161
    static let prime4:UInt64 = 9650029242287828579
    static let prime5:UInt64 = 2870177450012600261
}

struct XXHash {
    var s1: UInt64
    var s2: UInt64
    var s3: UInt64
    var s4: UInt64

    let storage: [UInt8]
    var used: Int

    var count: Int

    init(seed: UInt64) {
        self.s1 = seed &+ XXPrimes.prime1 &+ XXPrimes.prime2
        self.s2 = seed &+ XXPrimes.prime2
        self.s3 = seed
        self.s4 = seed &- XXPrimes.prime1
        self.count = 0
        self.storage = Array<UInt8>(repeating: 0, count: 32)
        self.used = 0
    }


    static private func round(acc: UInt64, input: UInt64) -> UInt64 {
        var current = acc

        current = current &+ input &* XXPrimes.prime2
        current = current.rol(x: 31)
        current = current &* XXPrimes.prime1
        return current
    }

    static private func merge(acc: UInt64, input: UInt64) -> UInt64 {
        var current = acc ^ round(acc: 0, input: input)

        current = current &* XXPrimes.prime1 &+ XXPrimes.prime4
        return current
    }

    mutating func update(buffer: [UInt8]) {
        guard let unsafeBuffer = buffer.withUnsafeBufferPointer({ return $0.baseAddress }),
            let storagePointer =  storage.withUnsafeBufferPointer({ return $0.baseAddress }) else { return }

        let rawStoragePointer = UnsafeMutableRawPointer(mutating: storagePointer)

        // End of buffer
        let bufferEndPointer = unsafeBuffer.advanced(by: buffer.count)

        // Movable pointer to input buffer
        var bufferPointer = unsafeBuffer

        self.count += buffer.count

        if used + buffer.count  < 32 {
            rawStoragePointer.advanced(by: used).copyBytes(from: bufferPointer, count: buffer.count)
            used += buffer.count
            return
        }

        // Storage buffer not empty
        if used > 0 {
            rawStoragePointer.advanced(by: used).copyBytes(from: bufferPointer, count: 32 - used)

            storagePointer.withMemoryRebound(to: UInt64.self, capacity: 4) {
                s1 = XXHash.round(acc: s1, input: $0[0])
                s2 = XXHash.round(acc: s2, input: $0[1])
                s3 = XXHash.round(acc: s3, input: $0[2])
                s4 = XXHash.round(acc: s4, input: $0[3])
            }


            // Advance input buffer pointer
            bufferPointer = bufferPointer.advanced(by: 32 - used)

            // Reset Storage buffer usage
            used = 0
        }

        if bufferPointer.advanced(by: 32) <= bufferEndPointer {
            let limit = bufferEndPointer.advanced(by: -32)

            repeat {
                bufferPointer.withMemoryRebound(to: UInt64.self, capacity: 4) { items in
                    s1 = XXHash.round(acc: s1, input: items[0])
                    s2 = XXHash.round(acc: s2, input: items[1])
                    s3 = XXHash.round(acc: s3, input: items[2])
                    s4 = XXHash.round(acc: s4, input: items[3])
                }

                // Advance pointer to next 32 byte block
                bufferPointer = bufferPointer.advanced(by: 32)
            } while bufferPointer <= limit
        }

        // Copy any leftovers into state storage.
        if bufferPointer < bufferEndPointer {
            let remainingCount = bufferEndPointer - bufferPointer

            rawStoragePointer.advanced(by: used).copyBytes(from: bufferPointer, count: remainingCount)
            used += remainingCount
        }
    }


    func digest() -> UInt64 {
        let storageBufferPointer = storage.withUnsafeBufferPointer { return $0 }

        // Base Pointers
        guard let storagePointer = storageBufferPointer.baseAddress else { return 0 }

        let storageEndPointer = storagePointer.advanced(by: used)
        var currentStoragePointer = storagePointer

        var hash = s3 &+ XXPrimes.prime5

        if count >= 32 {
            hash = s1.rol(x: 1) &+ s2.rol(x: 7) &+ s3.rol(x: 12) &+ s4.rol(x:18)

            hash = XXHash.merge(acc: hash, input: s1)
            hash = XXHash.merge(acc: hash, input: s2)
            hash = XXHash.merge(acc: hash, input: s3)
            hash = XXHash.merge(acc: hash, input: s4)
        }

        hash = hash &+ UInt64(count)

        // Process remaining 64-bit blocks
        currentStoragePointer.withMemoryRebound(to: UInt64.self, capacity: used/8) { items in
            for item in UnsafeBufferPointer(start: items, count: used/8) {
                hash ^= XXHash.round(acc: 0, input: item)
                hash = hash.rol(x: 27) &* XXPrimes.prime1 &+ XXPrimes.prime4
            }
        }

        // Process remaining bytes.
        currentStoragePointer = currentStoragePointer.advanced(by: used - (used % 8))

        if storageEndPointer - currentStoragePointer >= 4 {
            let rawPointer = UnsafeRawPointer(currentStoragePointer)
            let value = rawPointer.load(as: UInt32.self)

            currentStoragePointer = currentStoragePointer.advanced(by: 4)

            hash ^= UInt64(value) &* XXPrimes.prime1
            hash = hash.rol(x: 23) &* XXPrimes.prime2 &+ XXPrimes.prime3
        }

        hash = UnsafeBufferPointer(start: currentStoragePointer, count: storageEndPointer - currentStoragePointer).reduce(hash) { acc, next -> UInt64 in
            var acc = acc
            acc ^= UInt64(next) &* XXPrimes.prime5
            acc = acc.rol(x: 11) &* XXPrimes.prime1
            return acc
        }

        hash ^= hash >> 33
        hash = hash &* XXPrimes.prime2
        hash ^= hash >> 29
        hash = hash &* XXPrimes.prime3
        hash ^= hash >> 32
        return hash
    }
}

extension UInt64 {
    func rol(x: UInt64) -> UInt64 {
        return self << x | self >> (64 - x)
    }
}

