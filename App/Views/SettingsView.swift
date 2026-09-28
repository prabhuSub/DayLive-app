import SwiftUI
import UIKit

/// Settings tab: appearance, categories, auto rules, Live Activity, sample data.
struct SettingsView: View {
    @EnvironmentObject private var categories: CategoryStore
    @EnvironmentObject private var activity: LiveActivityManager
    @EnvironmentObject private var history: HistoryStore
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue

    @State private var editingCategory: Category?
    @State private var addingRule = false
    @State private var editingCalendar: CalendarPick?

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(section: "Settings")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Caps("Appearance")
                        PillNav(options: Appearance.allCases,
                                selection: Binding(get: { Appearance(rawValue: appearance) ?? .system },
                                                   set: { appearance = $0.rawValue })) { $0.label }
                    }
                    .cardBox()

                    VStack(alignment: .leading, spacing: 10) {
                        Caps("Categories")
                        FlowLayout(spacing: 8) {
                            ForEach(categories.categories) { c in
                                Chip(title: c.name, color: c.color) { editingCategory = c }
                            }
                            Chip(title: "+ New") {
                                editingCategory = Category(id: UUID().uuidString, name: "",
                                                           colorHex: CategoryStore.palette[categories.categories.count % CategoryStore.palette.count])
                            }
                        }
                        Text("Tap a category to rename it or change its color.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.faint)
                    }
                    .cardBox()

                    calendarsCard

                    rulesCard

                    VStack(alignment: .leading, spacing: 10) {
                        Caps("Live Activity")
                        Toggle(isOn: $activity.autoStart) {
                            Text("Start automatically when the day has blocks")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.text)
                        }
                        .tint(Theme.blue)
                        Text(activity.statusText)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                        Button("Open iOS Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .cardBox()

                    VStack(alignment: .leading, spacing: 10) {
                        Caps("Sample data")
                        Text(history.hasDemo
                             ? "Sample data is loaded: 8 weeks of history and a planned day. Your real calendars are never touched."
                             : "Fill Today, Calendar and Stats with 8 sample weeks to preview the look. Your real calendars are never touched.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                        Button(history.hasDemo ? "Remove sample data" : "Load sample data") {
                            if history.hasDemo { DemoData.remove() } else { DemoData.load() }
                            Task { await activity.refresh() }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .cardBox()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Theme.section)
        }
        .sheet(item: $editingCategory) { c in
            CategoryEditorSheet(category: c, isNew: categories.category(id: c.id) == nil)
                .presentationDetents([.medium])
        }
        .sheet(item: $editingCalendar) { pick in
            CalendarColorSheet(pick: pick)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $addingRule) {
            RuleEditorSheet()
                .presentationDetents([.medium])
        }
    }

    private var calendarsCard: some View {
        let list = CalendarService.shared.calendarList()
        return VStack(alignment: .leading, spacing: 0) {
            Caps("Calendars").padding(.bottom, 8)
            if list.isEmpty {
                Text("Allow calendar access to color your calendars.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            ForEach(list, id: \.name) { item in
                let custom = categories.calendarColorHex(item.name)
                Button {
                    editingCalendar = CalendarPick(name: item.name, iosHex: item.hex)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(custom.map { Color(hex: $0) } ?? Color.clear)
                            .overlay(Circle().stroke(custom == nil ? Theme.faint : Color.clear, lineWidth: 1.5))
                            .frame(width: 12, height: 12)
                        Text(item.name)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Spacer()
                        Text(custom == nil ? "By category" : "Custom")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.faint)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
            }
            Text("A calendar color beats the category color everywhere except Stats. Tesla calendars start as Tesla red.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.faint)
                .padding(.top, 8)
        }
        .cardBox()
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Caps("Auto rules · first match wins")
                Spacer()
                Button("+ Add") { addingRule = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.blue)
                    .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            ForEach(Array(categories.rules.enumerated()), id: \.element.id) { index, rule in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(rule.kind.label) “\(rule.keywords)”")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.text)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Circle().fill(categories.category(id: rule.categoryID)?.color ?? Theme.faint)
                                .frame(width: 8, height: 8)
                            Text(categories.category(id: rule.categoryID)?.name ?? "—")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Spacer()
                    if index > 0 {
                        iconButton("arrow.up", label: "Move up") { categories.moveRuleUp(id: rule.id) }
                    }
                    iconButton("xmark", label: "Delete rule") { categories.deleteRule(id: rule.id) }
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
            }

            HStack {
                Text("Everything else")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text)
                Spacer()
                Menu {
                    ForEach(categories.categories) { c in
                        Button(c.name) { categories.fallbackID = c.id }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(categories.fallback.color).frame(width: 8, height: 8)
                        Text(categories.fallback.name).font(.system(size: 12))
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                    }
                    .foregroundStyle(Theme.muted)
                }
            }
            .padding(.vertical, 10)
            .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
        }
        .cardBox()
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 28, height: 28)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.border, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Category editor

struct CategoryEditorSheet: View {
    @State var category: Category
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = CategoryStore.shared

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Caps("Name")
                    TextField("Category name", text: $category.name)
                        .font(.system(size: 20, weight: .semibold))
                }
                .cardBox()

                VStack(alignment: .leading, spacing: 10) {
                    Caps("Color")
                    FlowLayout(spacing: 10) {
                        ForEach(CategoryStore.palette, id: \.self) { hex in
                            Button { category.colorHex = hex } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(Theme.text, lineWidth: category.colorHex == hex ? 2 : 0).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(hex)")
                        }
                    }
                }
                .cardBox()

                if !isNew && store.categories.count > 1 {
                    Button("Delete category") {
                        store.delete(id: category.id)
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .foregroundStyle(Theme.red)
                }
                Spacer()
            }
            .padding(20)
            .background(Theme.section)
            .navigationTitle(isNew ? "New category" : "Edit category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        category.name = category.name.trimmingCharacters(in: .whitespaces)
                        store.upsert(category)
                        Task { await LiveActivityManager.shared.refresh() }
                        dismiss()
                    }
                    .disabled(category.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Rule editor

struct RuleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = CategoryStore.shared

    @State private var kind: CategoryRule.Kind = .title
    @State private var keywords = ""
    @State private var categoryID: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Caps("When")
                    PillNav(options: CategoryRule.Kind.allCases, selection: $kind) { $0.label }
                    TextField(kind == .title ? "gym, run, yoga" : "Tesla", text: $keywords)
                        .font(.system(size: 17))
                        .textInputAutocapitalization(.never)
                    Text("Separate words with commas. Not case-sensitive.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                }
                .cardBox()

                VStack(alignment: .leading, spacing: 10) {
                    Caps("Then category")
                    FlowLayout(spacing: 8) {
                        ForEach(store.categories) { c in
                            Chip(title: c.name, color: c.color, selected: categoryID == c.id) { categoryID = c.id }
                        }
                    }
                }
                .cardBox()
                Spacer()
            }
            .padding(20)
            .background(Theme.section)
            .navigationTitle("New rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let categoryID {
                            store.addRule(CategoryRule(kind: kind, keywords: keywords, categoryID: categoryID))
                            Task { await LiveActivityManager.shared.refresh() }
                        }
                        dismiss()
                    }
                    .disabled(categoryID == nil || keywords.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Calendar color

struct CalendarPick: Identifiable {
    var id: String { name }
    let name: String
    let iosHex: String
}

struct CalendarColorSheet: View {
    let pick: CalendarPick
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = CategoryStore.shared

    var body: some View {
        let current = store.calendarColorHex(pick.name)
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Caps("Color for \(pick.name)")
                    FlowLayout(spacing: 10) {
                        ForEach([pick.iosHex] + CategoryStore.palette, id: \.self) { hex in
                            Button { choose(hex) } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay(Circle().stroke(Theme.text, lineWidth: current == hex ? 2 : 0).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(hex == pick.iosHex ? "iOS color" : "Color \(hex)")
                        }
                    }
                    Text("First swatch is this calendar's color in the iOS Calendar app.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                }
                .cardBox()

                Button("Use category colors instead") { choose("category") }
                    .buttonStyle(SecondaryButtonStyle())
                Spacer()
            }
            .padding(20)
            .background(Theme.section)
            .navigationTitle(pick.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func choose(_ hex: String) {
        store.calendarColors[pick.name] = hex
        Task { await LiveActivityManager.shared.refresh() }
    }
}
