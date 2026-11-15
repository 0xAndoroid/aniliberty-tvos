public struct LoginRequest: BackendAPIRequest {
    typealias ResponseObject = LoginResponse

    var requestData: RequestData

    init(login: String, password: String) {
        requestData = .init(
            endpoint: "/accounts/users/auth/login",
            method: .POST,
            body: LoginBody(login: login, password: password)
        )
    }

    init(provider: AuthProviderData) {
        requestData = .init(
            endpoint: "/accounts/users/auth/social/authenticate",
            method: .GET,
            parameters: ["state": provider.state]
        )
    }

    init(otpCode: String, deviceID: String) {
        requestData = .init(
            endpoint: "/accounts/otp/login",
            method: .POST,
            body: ["code": otpCode, "device_id": deviceID]
        )
    }
}

private struct LoginBody: Encodable {
    let login: String
    let password: String
}

struct LoginResponse: Decodable {
    let token: String
}
