# Live Cover Studio

一个 macOS SwiftUI 原型，用来给 Live Photo 更换封面并导出新的图片/MOV 资源对。

## 功能

- 选择 Live Photo 的静态图片资源和对应 MOV 资源
- 使用 `PHLivePhotoView` 预览原始 Live Photo
- 从 MOV 提取第一帧作为封面
- 支持导入外部图片替换封面
- 支持本地 Core Image 风格效果：电影感、鲜明、黑白、漫画、柔光
- 使用处理后的封面生成临时预览资源，并预览处理后的 Live Photo
- 导出带匹配资源标识的 JPG 和 MOV
- 直接保存到 macOS「照片」App，创建一张真正的 Live Photo 资产

## 运行

```sh
./script/build_and_run.sh
```

脚本会把 SwiftPM 产物包装成 `dist/LiveCoverStudio.app` 后启动，这样窗口激活和系统 Live Photo 预览更接近普通 Mac 应用。

如果只想确认编译：

```sh
swift build
```

## 构建和打包命令

项目使用 SwiftPM 构建，`script/build_and_run.sh` 会把可执行文件包装成标准 macOS `.app` 结构，并进行本地 ad-hoc 签名。

| 用途                     | 命令                                  | 产物/说明                                                                |
| ------------------------ | ------------------------------------- | ------------------------------------------------------------------------ |
| 仅编译检查               | `swift build`                         | 生成 SwiftPM debug 产物                                                  |
| 构建 `.app` 并启动       | `./script/build_and_run.sh`           | 生成 `dist/LiveCoverStudio.app` 并打开                                   |
| 构建 `.app` 并验证可启动 | `./script/build_and_run.sh --verify`  | 启动后检查 `LiveCoverStudio` 进程                                        |
| 构建 `.app` 并进入 LLDB  | `./script/build_and_run.sh --debug`   | 用 `lldb` 调试 `dist/LiveCoverStudio.app/Contents/MacOS/LiveCoverStudio` |
| 构建 `.app` 并查看日志   | `./script/build_and_run.sh --logs`    | 启动 App 后打开 `log stream`                                             |
| 构建 `.app` 并打 zip 包  | `./script/build_and_run.sh --package` | 生成 `dist/LiveCoverStudio.zip`                                          |
| 构建 `.app` 并打 dmg 包  | `./script/build_and_run.sh --dmg`     | 生成 `dist/LiveCoverStudio.dmg`                                          |

打包脚本会先清理旧的 `dist/LiveCoverStudio.app`，复制图标和 `Info.plist`，再执行：

```sh
/usr/bin/codesign --force --deep --sign - dist/LiveCoverStudio.app
```

当前签名方式适合本机开发和分发测试包；如果要公开分发，还需要换成 Developer ID 签名并走 notarization。

## 快速验证流程

1. 启动 App 后点击「载入演示资源」
2. 左侧原始区域出现 Live Photo 预览
3. 点击「提取第一帧」
4. 选择一个效果，例如「漫画」或「黑白」
5. 右侧出现处理后的 Live Photo 预览
6. 点击「保存到照片」，在「照片」App 中查看真正的 Live Photo
7. 如需文件资源，再点击「导出资源对」

## 输入和导出说明

输入需要是一组 Live Photo 文件资源，通常是一张 `.heic` / `.jpg` 图片和一段 `.mov` 视频。导出时会生成：

- `*_cover.jpg`：处理后的封面图，写入 Apple Maker metadata 资源标识
- `*_motion.mov`：复制/封装后的动态视频，写入匹配的 QuickTime content identifier

如果原始 MOV 缺少 Live Photo 元数据，普通视频仍可抽帧和导出，但系统级 Live Photo 识别可能取决于源文件是否符合 Apple 的资源配对规则。

从 iCloud 网页或某些“保存图片”入口拿到的 `.jpg` 通常只是静态图，不包含 Live Photo 的动态部分。要保留实况效果，请从 macOS「照片」App 使用“导出未修改的原片”，或确保同时拿到同一组图片文件和 `.mov` 文件。

注意：Finder 里看到两个导出的文件是正常的资源对形态。想让它变成系统「照片」里的单个实况照片，请使用 App 内的「保存到照片」。
