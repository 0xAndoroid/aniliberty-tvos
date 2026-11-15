//
//  ProfileView.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import Combine
import SwiftUI

struct ProfileView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                if let user = app.user {
                    Text(user.name)
                        .font(.title2)
                        .foregroundStyle(Theme.text)
                    Button(L10n.Buttons.signOut) {
                        app.session.logout()
                    }
                } else {
                    Text(L10n.Common.guest)
                        .font(.title2)
                        .foregroundStyle(Theme.text)
                    Text("Вход открывает избранное и переносит прогресс просмотра между устройствами.")
                        .foregroundStyle(Theme.muted)
                    NavigationLink("Войти по коду") {
                        CodeSignInView()
                    }
                    NavigationLink("Войти по паролю") {
                        PasswordSignInView()
                    }
                }
            }
        }
    }
}

/// Shows a one-time code and waits until the user accepts it from a signed-in device.
private struct CodeSignInView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var code: String?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 40) {
            Text("Откройте AniLiberty на устройстве, где вы уже вошли, выберите «\(L10n.Screen.LinkDevice.title)» и введите код")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
            if let code {
                Text(code)
                    .font(.system(size: 140, weight: .bold, design: .monospaced))
                    .tracking(16)
                    .foregroundStyle(Theme.text)
            } else {
                ProgressView()
            }
            if let error {
                Text(error)
                    .foregroundStyle(Theme.brand)
            }
            Button(L10n.Buttons.cancel) {
                dismiss()
            }
        }
        .frame(maxWidth: 1200)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await signIn()
        }
    }

    private func signIn() async {
        while !Task.isCancelled {
            let deviceID = UUID().uuidString
            do {
                let otp = try await app.session.getOTP(deviceID: deviceID).firstValue()
                code = otp.code
                error = nil
                _ = try await app.session.signIn(otpCode: otp.code, deviceID: deviceID)
                    .timeout(.seconds(otp.remainingTime), scheduler: DispatchQueue.main)
                    .firstValue()
                dismiss()
                return
            } catch {
                // The code expired or a request failed: show a new code after a pause.
                code = nil
                if !(error is CancellationError) {
                    self.error = error.message
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
}

private struct PasswordSignInView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var login = ""
    @State private var password = ""
    @State private var error: String?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 30) {
            TextField(L10n.Screen.Auth.login, text: $login)
                .textContentType(.username)
                .keyboardType(.emailAddress)
            SecureField(L10n.Screen.Auth.password, text: $password)
                .textContentType(.password)
            Button(L10n.Buttons.signIn) {
                Task { await signIn() }
            }
            .disabled(login.isEmpty || password.isEmpty || isSigningIn)
            if let error {
                Text(error)
                    .foregroundStyle(Theme.brand)
            }
        }
        .frame(maxWidth: 900)
        .toolbar(.hidden, for: .tabBar)
    }

    private func signIn() async {
        isSigningIn = true
        error = nil
        do {
            _ = try await app.session.signIn(login: login, password: password).firstValue()
            dismiss()
        } catch {
            self.error = error.message
        }
        isSigningIn = false
    }
}
