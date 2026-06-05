import SwiftUI

@available(iOS 16, *)
struct WebsiteSettingsView: View {
    @StateObject private var manager = FokusModeManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var showingAddDomain = false
    @State private var newDomain = ""
    @State private var expandedCategories: Set<UUID> = []
    @Environment(\.colorScheme) var colorScheme

    var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    categoriesSection
                    manualDomainsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(String(localized: "wsv_nav_title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newDomain = ""
                    showingAddDomain = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showingAddDomain) {
            addDomainSheet
        }
    }

    // MARK: - Categories Section

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: String(localized: "wsv_categories_title"), subtitle: String(localized: "wsv_categories_subtitle"))

            VStack(spacing: 10) {
                ForEach(websiteBlockCategories) { category in
                    categoryRow(category)
                }
            }
        }
    }

    private func categoryRow(_ category: WebsiteBlockCategory) -> some View {
        let allAdded = category.domains.allSatisfy { manager.blockedDomains.contains($0) }
        let someAdded = category.domains.contains { manager.blockedDomains.contains($0) }
        let addedCount = category.domains.filter { manager.blockedDomains.contains($0) }.count
        let isExpanded = expandedCategories.contains(category.id)

        return VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded {
                        expandedCategories.remove(category.id)
                    } else {
                        expandedCategories.insert(category.id)
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(category.color.opacity(0.20))
                            .frame(width: 46, height: 46)
                        Image(systemName: category.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(category.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isDark ? .white : .primary)
                        Text(allAdded
                             ? String(format: String(localized: "wsv_cat_all_blocked"), category.domains.count)
                             : someAdded
                                ? String(format: String(localized: "wsv_cat_some_blocked"), addedCount, category.domains.count)
                                : String(format: String(localized: "wsv_cat_domain_count"), category.domains.count))
                            .font(.caption)
                            .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isDark ? .white.opacity(0.3) : Color.secondary.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if allAdded {
                                category.domains.forEach { manager.removeDomain($0) }
                            } else {
                                category.domains.forEach { manager.addDomain($0) }
                            }
                        }
                    } label: {
                        Text(allAdded ? String(localized: "wsv_remove") : String(localized: "wsv_all"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(allAdded ? Color.red.opacity(0.15) : category.color.opacity(0.18))
                            .foregroundStyle(allAdded ? .red : category.color)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(
                                allAdded ? Color.red.opacity(0.35) : category.color.opacity(0.35),
                                lineWidth: 1
                            ))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded domain list
            if isExpanded {
                Divider()
                    .background(category.color.opacity(0.2))
                    .padding(.horizontal, 12)

                VStack(spacing: 0) {
                    ForEach(category.domains, id: \.self) { domain in
                        let isBlocked = manager.blockedDomains.contains(domain)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isBlocked {
                                    manager.removeDomain(domain)
                                } else {
                                    manager.addDomain(domain)
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isBlocked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(isBlocked ? category.color : (isDark ? .white.opacity(0.25) : Color.secondary.opacity(0.4)))
                                    .frame(width: 20)
                                Text(domain)
                                    .font(.system(size: 13))
                                    .foregroundStyle(isBlocked ? (isDark ? .white.opacity(0.9) : .primary) : (isDark ? .white.opacity(0.5) : Color.secondary))
                                    .strikethrough(isBlocked, color: (isDark ? .white.opacity(0.3) : Color.secondary.opacity(0.4)))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if domain != category.domains.last {
                            Divider()
                                .background(category.color.opacity(0.08))
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .themeGlass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(someAdded ? category.color.opacity(0.45) : Color.clear, lineWidth: 1.5)
        )
        .clipped()
    }

    // MARK: - Manual Domains Section

    private var manualDomainsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: String(localized: "wsv_individual_title"),
                subtitle: manager.blockedDomains.isEmpty
                    ? String(localized: "wsv_individual_none")
                    : manager.blockedDomains.count == 1
                        ? String(localized: "wsv_individual_count_one")
                        : String(format: String(localized: "wsv_individual_count_many"), manager.blockedDomains.count)
            )

            if manager.blockedDomains.isEmpty {
                emptyDomainsPlaceholder
            } else {
                VStack(spacing: 8) {
                    ForEach(manager.blockedDomains, id: \.self) { domain in
                        domainRow(domain)
                    }
                }
            }
        }
    }

    private func domainRow(_ domain: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(themeC1.opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeC1)
            }

            Text(domain)
                .font(.subheadline)
                .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    manager.removeDomain(domain)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.red.opacity(0.7))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .themeGlass(cornerRadius: 14)
    }

    private var emptyDomainsPlaceholder: some View {
        Button {
            newDomain = ""
            showingAddDomain = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(themeC1)
                Text(String(localized: "wsv_add_manually"))
                    .font(.subheadline)
                    .foregroundStyle(isDark ? .white.opacity(0.7) : .secondary)
                Spacer()
            }
            .padding(16)
            .themeGlass(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(themeC1.opacity(0.4))
            )
        }
    }

    // MARK: - Add Domain Sheet

    private var addDomainSheet: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "wsv_enter_domain"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)

                        HStack {
                            Image(systemName: "globe")
                                .foregroundStyle(themeC1)
                            TextField(String(localized: "wsv_domain_placeholder"), text: $newDomain)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onSubmit { submitDomain() }
                        }
                        .padding(14)
                        .themeGlass(cornerRadius: 12)

                        Text(String(localized: "wsv_domain_hint"))
                            .font(.caption)
                            .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                    }

                    Button {
                        submitDomain()
                    } label: {
                        Text(String(localized: "wsv_add"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                newDomain.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AnyShapeStyle(Color.secondary.opacity(0.3))
                                    : AnyShapeStyle(LinearGradient(colors: [themeC1, themeC2],
                                                                   startPoint: .leading, endPoint: .trailing))
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(newDomain.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(String(localized: "wsv_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "ki_cancel")) { showingAddDomain = false }
                }
            }
        }
        .presentationDetents([.height(280)])
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(isDark ? .white : .primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
        }
    }

    private func submitDomain() {
        let trimmed = newDomain.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        manager.addDomain(trimmed)
        newDomain = ""
        showingAddDomain = false
    }
}

#Preview {
    if #available(iOS 16, *) {
        NavigationStack {
            WebsiteSettingsView()
        }
    }
}
