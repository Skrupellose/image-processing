import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: LivePhotoViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            DetailView(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.chooseResources()
                } label: {
                    Label("选择资源", systemImage: "photo.badge.plus")
                }
                .help("选择 Live Photo 的图片和 MOV 文件")

                Button {
                    viewModel.saveProcessedLivePhotoToPhotos()
                } label: {
                    Label("保存到照片", systemImage: "photo.badge.checkmark")
                }
                .disabled(!viewModel.canExport || viewModel.isBusy)
                .help("保存为照片 App 里的 Live Photo")
            }
        }
        .alert(
            "处理失败",
            isPresented: Binding(
                get: { viewModel.alertMessage != nil },
                set: { if !$0 { viewModel.alertMessage = nil } }
            )
        ) {
            Button("好") {
                viewModel.alertMessage = nil
            }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
    }
}
