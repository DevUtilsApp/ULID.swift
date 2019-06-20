//
//  Data+Base32.swift
//  ULID
//
//  Created by Yasuhiro Hatta on 2019/01/11.
//  Copyright © 2019 yaslab. All rights reserved.
//

import Foundation

enum Base32 {

    static let crockfordsEncodingTable: [UInt8] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".utf8.map({ $0 })

    static let crockfordsDecodingTable: [UInt8] = [
        // 0     1     2     3     4     5     6     7     8     9     a     b     c     d     e     f
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // 0
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // 1
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // 2
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // 3
        0xff, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x01, 0x12, 0x13, 0x01, 0x14, 0x15, 0x00, // 4
        0x16, 0x17, 0x18, 0x19, 0x1a, 0xff, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0xff, 0xff, 0xff, 0xff, 0xff, // 5
        0xff, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x01, 0x12, 0x13, 0x01, 0x14, 0x15, 0x00, // 6
        0x16, 0x17, 0x18, 0x19, 0x1a, 0xff, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0xff, 0xff, 0xff, 0xff, 0xff, // 7
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // 8
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // 9
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // a
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // b
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // c
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // d
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, // e
        0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff  // f
    ]

}

extension Data {

    /// Decode Crockford's Base32
    init?(base32Encoded base32String: String, using table: [UInt8] = Base32.crockfordsDecodingTable) {
        var base32String = base32String
        while let last = base32String.last, last == "=" {
            base32String.removeLast()
        }

        let result: Data? = base32String.withCString(encodedAs: Unicode.UTF8.self) { (src) in
            func _strlen(_ str: UnsafePointer<UInt8>) -> Int {
                var str = str
                var i = 0
                while str.pointee != 0 {
                    str += 1
                    i += 1
                }
                return i
            }

            let srclen = _strlen(src)
            guard [0, 2, 4, 5, 7].contains(srclen % 8) else {
                return nil
            }

            let dstlen = srclen * 5 / 8

            var buffer = Data(count: dstlen)
            let success: Bool = buffer.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Bool in
                var srcleft = srclen
                var srcp = src

                var dsti: UnsafeMutableRawBufferPointer.Index = 0

                let work = UnsafeMutablePointer<UInt8>.allocate(capacity: 8)
                defer { work.deallocate() }

                while srcleft > 0 {
                    let worklen = Swift.min(8, srcleft)
                    for i in 0 ..< worklen {
                        work[i] = table[Int(srcp[i])]
                        if work[i] == 0xff {
                            return false
                        }
                    }

                    switch worklen {
                    case 8:
                        dst[dsti + 4] = (work[6] << 5) | (work[7]     )
                        fallthrough
                    case 7:
                        dst[dsti + 3] = (work[4] << 7) | (work[5] << 2) | (work[6] >> 3)
                        fallthrough
                    case 5:
                        dst[dsti + 2] = (work[3] << 4) | (work[4] >> 1)
                        fallthrough
                    case 4:
                        dst[dsti + 1] = (work[1] << 6) | (work[2] << 1) | (work[3] >> 4)
                        fallthrough
                    case 2:
                        dst[dsti + 0] = (work[0] << 3) | (work[1] >> 2)
                    default:
                        break
                    }

                    srcp += 8
                    srcleft -= 8
                    dsti += 5
                }

                return true
            }

            guard success else {
                return nil
            }

            return buffer
        }

        guard let data = result else {
            return nil
        }

        self = data
    }

    /// Encode Crockford's Base32
    func base32EncodedString(padding: Bool = true, using table: [UInt8] = Base32.crockfordsEncodingTable) -> String {
        var srcleft = self.count

        let dstlen: Int
        if padding {
            dstlen = (self.count + 4) / 5 * 8
        } else {
            dstlen = (self.count * 8 + 4) / 5
        }
        var dstleft = dstlen

        return self.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> String in
            var srci: UnsafeRawBufferPointer.Index = 0

            let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: dstlen + 1)
            var dstp = dst
            defer { dst.deallocate() }

            let work = UnsafeMutablePointer<UInt8>.allocate(capacity: 8)
            work.initialize(repeating: 0, count: 8)
            defer { work.deallocate() }

            while srcleft > 0 {
                switch srcleft {
                case _ where 5 <= srcleft:
                    work[7]  = src[srci + 4]
                    work[6]  = src[srci + 4] >> 5
                    fallthrough
                case 4:
                    work[6] |= src[srci + 3] << 3
                    work[5]  = src[srci + 3] >> 2
                    work[4]  = src[srci + 3] >> 7
                    fallthrough
                case 3:
                    work[4] |= src[srci + 2] << 1
                    work[3]  = src[srci + 2] >> 4
                    fallthrough
                case 2:
                    work[3] |= src[srci + 1] << 4
                    work[2]  = src[srci + 1] >> 1
                    work[1]  = src[srci + 1] >> 6
                    fallthrough
                case 1:
                    work[1] |= src[srci + 0] << 2
                    work[0]  = src[srci + 0] >> 3
                default:
                    break
                }

                for i in 0 ..< Swift.min(8, dstleft) {
                    dstp[i] = table[Int(work[i] & 0x1f)]
                }

                if srcleft < 5 {
                    if padding {
                        switch srcleft {
                        case 1:
                            dstp[2] = "=".utf8.first!
                            dstp[3] = "=".utf8.first!
                            fallthrough
                        case 2:
                            dstp[4] = "=".utf8.first!
                            fallthrough
                        case 3:
                            dstp[5] = "=".utf8.first!
                            dstp[6] = "=".utf8.first!
                            fallthrough
                        case 4:
                            dstp[7] = "=".utf8.first!
                        default:
                            break
                        }
                    }
                    break
                }

                srci += 5
                srcleft -= 5
                dstp += 8
                dstleft -= 8
            }

            dst[dstlen] = 0
            return String(cString: dst)
        }
    }

}
