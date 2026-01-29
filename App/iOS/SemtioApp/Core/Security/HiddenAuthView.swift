//
//  HiddenAuthView.swift
//  SemtioApp
//
//  Copyright © 2026 Oguzhan Cankaya ve Fikir Creative. All rights reserved.
//
//  Animated authentication view for hidden chats (FaceID + PIN).
//

import SwiftUI

enum HiddenAuthMode {
    case create  // First time PIN setup
    case verify  // Unlock hidden chats
}

struct HiddenAuthView: View {
    let mode: HiddenAuthMode
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @StateObject private var pinManager = HiddenPinManager.shared
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var isConfirming = false
    @State private var errorMessage: String?
    @State private var shakeOffset: CGFloat = 0
    @State private var isLoading = false
    @State private var biometricFailed = false
    @State private var enableFaceID = true

    private let pinLength = 6

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }

            // Modal Card
            VStack(spacing: Spacing.lg) {
                // Header
                headerView

                // PIN Display
                pinDotsView
                    .offset(x: shakeOffset)

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(AppColor.error)
                        .transition(.opacity)
                }

                // Lockout Warning
                if pinManager.isLocked {
                    lockoutView
                }

                // Keypad
                if !pinManager.isLocked && !isLoading {
                    numericKeypad
                }

                // Loading indicator
                if isLoading {
                    ProgressView()
                        .tint(Color.semtioPrimary)
                        .scaleEffect(1.2)
                        .padding(.vertical, Spacing.md)
                }

                // FaceID Toggle (show during create mode confirm step)
                if mode == .create && isConfirming && BiometricAuth.shared.isAvailable {
                    faceIDToggle
                }

                // Biometric Button (only in verify mode)
                if mode == .verify && BiometricAuth.shared.isAvailable && !biometricFailed {
                    biometricButton
                }

                // Cancel Button
                Button("Iptal") {
                    onCancel()
                }
                .foregroundColor(AppColor.textSecondary)
                .padding(.top, Spacing.sm)
            }
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .fill(AppColor.surface)
            )
            .padding(.horizontal, Spacing.lg)
            .transition(.scale.combined(with: .opacity))
        }
        .animation(.spring(response: 0.3), value: errorMessage)
        .animation(.spring(response: 0.3), value: isConfirming)
        .animation(.spring(response: 0.3), value: isLoading)
        .task {
            if mode == .verify {
                await tryBiometric()
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: headerIcon)
                .font(.system(size: 40))
                .foregroundColor(Color.semtioPrimary)

            Text(headerTitle)
                .font(.headline)
                .foregroundColor(AppColor.textPrimary)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var headerIcon: String {
        switch mode {
        case .create:
            return isConfirming ? "lock.rotation" : "lock.badge.plus"
        case .verify:
            return "lock.fill"
        }
    }

    private var headerTitle: String {
        switch mode {
        case .create:
            return isConfirming ? "Sifreyi Onayla" : "Sifre Olustur"
        case .verify:
            return "Gizli Sohbetler"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .create:
            return isConfirming
                ? "Sifreyi tekrar girin"
                : "6 haneli bir sifre belirleyin"
        case .verify:
            return "Erisim icin sifrenizi girin"
        }
    }

    private var pinDotsView: some View {
        HStack(spacing: Spacing.md) {
            ForEach(0..<pinLength, id: \.self) { index in
                Circle()
                    .fill(index < currentPin.count ? Color.semtioPrimary : AppColor.border)
                    .frame(width: 16, height: 16)
                    .scaleEffect(index < currentPin.count ? 1.1 : 1.0)
                    .animation(.spring(response: 0.2), value: currentPin.count)
            }
        }
        .padding(.vertical, Spacing.md)
    }

    private var currentPin: String {
        isConfirming ? confirmPin : pin
    }

    private var numericKeypad: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<3) { row in
                HStack(spacing: Spacing.lg) {
                    ForEach(1...3, id: \.self) { col in
                        let number = row * 3 + col
                        keypadButton(String(number))
                    }
                }
            }

            // Bottom row: empty, 0, delete
            HStack(spacing: Spacing.lg) {
                Color.clear
                    .frame(width: 70, height: 70)

                keypadButton("0")

                Button(action: deleteDigit) {
                    Image(systemName: "delete.left.fill")
                        .font(.title2)
                        .foregroundColor(AppColor.textPrimary)
                        .frame(width: 70, height: 70)
                }
            }
        }
    }

    private func keypadButton(_ digit: String) -> some View {
        Button(action: { addDigit(digit) }) {
            Text(digit)
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(AppColor.textPrimary)
                .frame(width: 70, height: 70)
                .background(
                    Circle()
                        .fill(AppColor.surfaceSecondary)
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var faceIDToggle: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: BiometricAuth.shared.biometricIcon)
                .font(.system(size: 20))
                .foregroundColor(Color.semtioPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(BiometricAuth.shared.biometricName) ile Ac")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColor.textPrimary)

                Text("Sifre yerine \(BiometricAuth.shared.biometricName) kullan")
                    .font(.caption)
                    .foregroundColor(AppColor.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $enableFaceID)
                .labelsHidden()
                .tint(Color.semtioPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(AppColor.surfaceSecondary)
        )
    }

    private var biometricButton: some View {
        Button(action: {
            Task { await tryBiometric() }
        }) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: BiometricAuth.shared.biometricIcon)
                Text(BiometricAuth.shared.biometricName + " ile Ac")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(Color.semtioPrimary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                Capsule()
                    .stroke(Color.semtioPrimary, lineWidth: 1.5)
            )
        }
    }

    private var lockoutView: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "lock.slash.fill")
                .font(.title)
                .foregroundColor(AppColor.error)

            Text("Cok fazla hatali deneme")
                .font(.subheadline)
                .foregroundColor(AppColor.textPrimary)

            Text(lockoutTimeString)
                .font(.caption)
                .foregroundColor(AppColor.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Radius.md)
                .fill(AppColor.error.opacity(0.1))
        )
    }

    private var lockoutTimeString: String {
        let seconds = Int(pinManager.remainingLockoutTime)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d sonra tekrar deneyin", minutes, remainingSeconds)
    }

    // MARK: - Actions

    private func addDigit(_ digit: String) {
        guard !isLoading else { return }

        let currentCount = isConfirming ? confirmPin.count : pin.count
        guard currentCount < pinLength else { return }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if isConfirming {
            confirmPin += digit
            if confirmPin.count == pinLength {
                Task { await handleConfirmComplete() }
            }
        } else {
            pin += digit
            if pin.count == pinLength {
                Task { await handlePinComplete() }
            }
        }
    }

    private func deleteDigit() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        if isConfirming {
            if !confirmPin.isEmpty {
                confirmPin.removeLast()
            }
        } else {
            if !pin.isEmpty {
                pin.removeLast()
            }
        }
        errorMessage = nil
    }

    private func handlePinComplete() async {
        switch mode {
        case .create:
            // Move to confirmation step
            withAnimation(.spring(response: 0.3)) {
                isConfirming = true
                errorMessage = nil
            }

        case .verify:
            isLoading = true
            let success = await pinManager.verifyPin(pin)
            isLoading = false

            if success {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                onSuccess()
            } else {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                await shake()
                errorMessage = "Hatali sifre"
                pin = ""
            }
        }
    }

    private func handleConfirmComplete() async {
        guard confirmPin == pin else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            await shake()
            errorMessage = "Sifreler eslesmiyor"
            confirmPin = ""
            return
        }

        // Pins match, save
        isLoading = true
        let success = await pinManager.setPin(pin)
        isLoading = false

        if success {
            // Save FaceID preference
            if enableFaceID && BiometricAuth.shared.isAvailable {
                UserDefaults.standard.set(true, forKey: "hiddenChatFaceIDEnabled")
            } else {
                UserDefaults.standard.set(false, forKey: "hiddenChatFaceIDEnabled")
            }

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            onSuccess()
        } else {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            await shake()
            errorMessage = "Sifre kaydedilemedi. Lutfen tekrar deneyin."
            pin = ""
            confirmPin = ""
            withAnimation(.spring(response: 0.3)) {
                isConfirming = false
            }
        }
    }

    private func tryBiometric() async {
        guard BiometricAuth.shared.isAvailable else { return }

        // Check if user disabled FaceID preference
        let hasKey = UserDefaults.standard.object(forKey: "hiddenChatFaceIDEnabled") != nil
        if hasKey && !UserDefaults.standard.bool(forKey: "hiddenChatFaceIDEnabled") {
            biometricFailed = true
            return
        }

        let success = await BiometricAuth.shared.authenticate(
            reason: "Gizli sohbetlere erisim icin dogrulayin"
        )

        if success {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            onSuccess()
        } else {
            biometricFailed = true
        }
    }

    private func shake() async {
        withAnimation(.default) { shakeOffset = 15 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        withAnimation(.default) { shakeOffset = -15 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        withAnimation(.default) { shakeOffset = 10 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        withAnimation(.default) { shakeOffset = -10 }
        try? await Task.sleep(nanoseconds: 50_000_000)
        withAnimation(.spring(response: 0.2)) { shakeOffset = 0 }
    }
}

// MARK: - Preview

#Preview("Create Mode") {
    HiddenAuthView(
        mode: .create,
        onSuccess: { print("Success!") },
        onCancel: { print("Cancelled") }
    )
}

#Preview("Verify Mode") {
    HiddenAuthView(
        mode: .verify,
        onSuccess: { print("Success!") },
        onCancel: { print("Cancelled") }
    )
}
