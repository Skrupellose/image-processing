import Foundation

enum LivePhotoProcessingError: LocalizedError {
    case missingResources
    case missingCoverImage
    case imageConversionFailed
    case imageWriteFailed
    case videoExportSessionUnavailable
    case videoExportFailed(String)
    case photosAccessDenied
    case photosSaveFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingResources:
            return "请先选择一张封面图和一段实况视频。"
        case .missingCoverImage:
            return "请先提取或更换封面图。"
        case .imageConversionFailed:
            return "封面图转换失败。"
        case .imageWriteFailed:
            return "封面图写入失败。"
        case .videoExportSessionUnavailable:
            return "无法创建视频导出任务。"
        case .videoExportFailed(let reason):
            return "视频导出失败：\(reason)"
        case .photosAccessDenied:
            return "没有照片图库权限，请在系统设置中允许 LiveCoverStudio 访问照片。"
        case .photosSaveFailed(let reason):
            return "保存到照片失败：\(reason)"
        case .cancelled:
            return "操作已取消。"
        }
    }
}
