import SwiftUI

/// Hyperday's own line icons (Assets › Icons, drawn by tools/make_icons.py). Tint with .foregroundStyle.
struct HDIcon: View {
    let name: String
    var size: CGFloat = 20

    init(_ name: String, size: CGFloat = 20) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("hd-\(name)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

enum HDIcons {
    /// Icons a category can use (Settings › Categories › icon).
    static let categoryChoices = ["work", "meetings", "deepwork", "fitness", "family", "personal",
                                  "learning", "health", "travel", "errands", "social", "code", "star"]

    static func defaultCategoryIcon(_ id: String) -> String {
        categoryChoices.contains(id) ? id : "star"
    }
}
