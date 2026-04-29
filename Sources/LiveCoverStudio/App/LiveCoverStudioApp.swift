import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        disableWindowTabbing()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        disableWindowTabbing()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func disableWindowTabbing() {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.windows.forEach { window in
            window.tabbingMode = .disallowed
        }
    }
}

@main
struct LiveCoverStudioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = LivePhotoViewModel()

    var body: some Scene {
        WindowGroup("Live Cover Studio") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("选择实况图片资源...") {
                    viewModel.chooseResources()
                }
                .keyboardShortcut("o")

                Button("导出处理后的实况图片...") {
                    viewModel.exportProcessedLivePhoto()
                }
                .keyboardShortcut("s")
                .disabled(!viewModel.canExport)

                Button("保存到照片") {
                    viewModel.saveProcessedLivePhotoToPhotos()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!viewModel.canExport)
            }
        }
    }
}
