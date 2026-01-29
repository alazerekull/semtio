//
//  ChatWalkthroughManager.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import SwiftUI

@MainActor
final class ChatWalkthroughManager: ObservableObject {
    @AppStorage("semtio_chat_walkthrough_completed") private var walkthroughCompleted: Bool = false
    @AppStorage("semtio_chat_walkthrough_version") private var completedVersion: Int = 0

    /// Increment this to re-trigger walkthrough after app updates with new features.
    static let currentWalkthroughVersion = 1

    @Published var isActive: Bool = false
    @Published var currentStepIndex: Int = 0
    @Published var targetFrames: [Int: CGRect] = [:]

    let steps: [WalkthroughStep] = WalkthroughStep.chatSteps

    var currentStep: WalkthroughStep? {
        guard currentStepIndex >= 0, currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    var shouldShow: Bool {
        !walkthroughCompleted || completedVersion < Self.currentWalkthroughVersion
    }

    func startIfNeeded() {
        guard shouldShow else { return }
        currentStepIndex = 0
        withAnimation(.easeOut(duration: 0.3)) {
            isActive = true
        }
    }

    func nextStep() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if currentStepIndex < steps.count - 1 {
                let nextIndex = currentStepIndex + 1
                // Skip swipe steps if no chat rows available
                if (nextIndex == 3 || nextIndex == 4) && targetFrames[3] == nil {
                    currentStepIndex = 5 // Jump to completion
                } else {
                    currentStepIndex = nextIndex
                }
            } else {
                complete()
            }
        }
    }

    func previousStep() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if currentStepIndex > 0 {
                let prevIndex = currentStepIndex - 1
                // Skip swipe steps backwards if no chat rows
                if (prevIndex == 3 || prevIndex == 4) && targetFrames[3] == nil {
                    currentStepIndex = 2
                } else {
                    currentStepIndex = prevIndex
                }
            }
        }
    }

    func skip() {
        complete()
    }

    func registerFrame(for stepId: Int, frame: CGRect) {
        guard stepId >= 0 else { return }
        targetFrames[stepId] = frame
    }

    private func complete() {
        withAnimation(.easeOut(duration: 0.3)) {
            isActive = false
        }
        walkthroughCompleted = true
        completedVersion = Self.currentWalkthroughVersion
    }
}
