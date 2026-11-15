//
//  GetOTPRequest.swift
//  Anilibria
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import Foundation

public struct GetOTPRequest: BackendAPIRequest {
    typealias ResponseObject = OTPData

    var requestData: RequestData = .init(
        endpoint: "/accounts/otp/get",
        method: .POST
    )

    init(deviceID: String) {
        requestData.body = ["device_id": deviceID]
    }
}

struct OTPData: Decodable {
    let code: String
    let remainingTime: TimeInterval

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeyString.self)
        code = try container.decode(required: "otp", "code")
        remainingTime = try container.decode(required: "remaining_time")
    }
}
