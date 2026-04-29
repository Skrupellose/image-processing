import Foundation

enum CoverEffect: String, CaseIterable, Identifiable {
    case original
    case cinematic
    case vivid
    case noir
    case comic
    case bloom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "原图"
        case .cinematic:
            return "电影感"
        case .vivid:
            return "鲜明"
        case .noir:
            return "黑白"
        case .comic:
            return "漫画"
        case .bloom:
            return "柔光"
        }
    }
}
