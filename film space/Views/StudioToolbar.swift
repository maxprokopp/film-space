//
//  StudioToolbar.swift
//  film space
//

import SwiftUI
import Combine

struct StudioToolbar: View {
    @Bindable var sceneState: SceneState
    @Bindable var cameraController: OrbitCameraController

    @State private var rotateDirection: Float = 0
    @State private var verticalDirection: Float = 0
    @State private var joystick: CGSize = .zero

    private let tick = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    private let rotationSpeed: Float = 0.03
    private let verticalSpeed: Float = 0.03
    private let joystickSpeed: Float = 0.05

    var body: some View {
        let noSelection = sceneState.selectedHumanID == nil
        let noLock = cameraController.lockedTransform == nil

        HStack(spacing: 0) {
            // Left group — trailing aligned. Edit: rotate/add/delete bodies.
            // Camera: focal-length toggle.
            HStack(spacing: 16) {
                Spacer(minLength: 0)

                if sceneState.mode == .edit {
                    holdButton(systemName: "arrow.counterclockwise", disabled: noSelection) { active in
                        rotateDirection = active ? 1 : 0
                    }

                    holdButton(systemName: "arrow.clockwise", disabled: noSelection) { active in
                        rotateDirection = active ? -1 : 0
                    }

                    VStack(spacing: 12) {
                        circleButton(systemName: "figure.stand") {
                            sceneState.addHuman()
                        }

                        circleButton(systemName: "trash", tint: .red, disabled: noSelection) {
                            sceneState.deleteSelectedHuman()
                        }
                    }
                } else {
                    focalLengthButton
                }
            }
            .frame(maxWidth: .infinity)

            modeToggle
                .fixedSize()
                .padding(.horizontal, 16)

            // Right group: movement (edit only) + lock/return (both modes).
            HStack(spacing: 16) {
                if sceneState.mode == .edit {
                    VStack(spacing: 12) {
                        holdButton(systemName: "arrow.up") { active in
                            verticalDirection = active ? 1 : 0
                        }

                        holdButton(systemName: "arrow.down") { active in
                            verticalDirection = active ? -1 : 0
                        }
                    }

                    Joystick(value: $joystick)
                }

                VStack(spacing: 12) {
                    if sceneState.mode == .camera {
                        circleButton(systemName: "figure.stand.line.dotted.figure.stand") {
                            cameraController.pendingShoulderPlacement = true
                        }
                    }

                    circleButton(systemName: "lock.fill") {
                        lockCamera()
                    }
                }

                VStack(spacing: 12) {
                    if sceneState.mode == .camera {
                        recordButton
                    }

                    circleButton(systemName: "arrow.uturn.backward", disabled: noLock) {
                        returnToLock()
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 24)
        .onReceive(tick) { _ in
            if rotateDirection != 0 {
                sceneState.rotateSelectedHuman(by: rotateDirection * rotationSpeed)
            }
            if verticalDirection != 0 {
                cameraController.moveVertically(by: verticalDirection * verticalSpeed)
            }
            if joystick != .zero {
                cameraController.moveHorizontally(by: Float(joystick.width) * joystickSpeed)
                cameraController.moveForward(by: Float(-joystick.height) * joystickSpeed)
            }
        }
    }

    private func lockCamera() {
        if sceneState.mode == .camera, let live = cameraController.liveCameraTransform {
            cameraController.lockedTransform = live
        } else {
            cameraController.lockEditPose()
        }
    }

    private func returnToLock() {
        if sceneState.mode == .edit {
            cameraController.returnToLockedTransform()
        } else {
            cameraController.pendingRecenter = true
        }
    }

    private var recordButton: some View {
        Button {
            sceneState.isRecording.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                    .frame(width: 56, height: 56)

                if sceneState.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.red)
                        .frame(width: 22, height: 22)
                } else {
                    Circle()
                        .fill(.red)
                        .frame(width: 30, height: 30)
                }
            }
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var focalLengthButton: some View {
        Button {
            sceneState.cycleFocalLength()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "camera.aperture")
                Text(sceneState.focalLength.label)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(height: 56)
            .padding(.horizontal, 18)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var modeToggle: some View {
        HStack(spacing: 4) {
            ForEach(AppMode.allCases, id: \.self) { mode in
                Button {
                    sceneState.mode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(sceneState.mode == mode ? .black : .white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background {
                            if sceneState.mode == mode {
                                Capsule().fill(.white)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }

    private func circleButton(
        systemName: String,
        tint: Color = .white,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            iconCircle(systemName: systemName, tint: tint)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }

    // Circular button that reports press/release for continuous (hold) actions.
    private func holdButton(
        systemName: String,
        tint: Color = .white,
        disabled: Bool = false,
        setActive: @escaping (Bool) -> Void
    ) -> some View {
        iconCircle(systemName: systemName, tint: tint)
            .opacity(disabled ? 0.4 : 1)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !disabled { setActive(true) } }
                    .onEnded { _ in setActive(false) }
            )
    }

    private func iconCircle(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 56, height: 56)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.15)))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
    }
}

// Analog joystick: returns a normalized vector (-1...1 per axis) while held,
// snapping back to zero on release. width = strafe, height = forward/back.
private struct Joystick: View {
    @Binding var value: CGSize
    var size: CGFloat = 104

    @State private var offset: CGSize = .zero
    private var thumbSize: CGFloat { size * 0.42 }

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().strokeBorder(.white.opacity(0.15)))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

            Circle()
                .fill(.white)
                .frame(width: thumbSize, height: thumbSize)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .offset(offset)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    let maxRadius = (size - thumbSize) / 2
                    var dx = gesture.translation.width
                    var dy = gesture.translation.height
                    let distance = sqrt(dx * dx + dy * dy)
                    if distance > maxRadius, distance > 0 {
                        let scale = maxRadius / distance
                        dx *= scale
                        dy *= scale
                    }
                    offset = CGSize(width: dx, height: dy)
                    value = CGSize(width: dx / maxRadius, height: dy / maxRadius)
                }
                .onEnded { _ in
                    offset = .zero
                    value = .zero
                }
        )
    }
}
