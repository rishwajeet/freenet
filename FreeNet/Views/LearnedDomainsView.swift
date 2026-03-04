import SwiftUI

// MARK: - Learned Domains View

struct LearnedDomainsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .recent
    @State private var filterClassification: DomainClassification?

    var body: some View {
        VStack(spacing: 0) {
            // Stats summary
            domainStats
                .padding(16)

            Divider()

            // Toolbar: search + filters
            toolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            Divider()

            // Domain list
            domainList
        }
    }

    // MARK: - Stats Summary

    private var domainStats: some View {
        HStack(spacing: 20) {
            DomainStat(
                label: "Total",
                value: appState.learnedDomains.count,
                color: .blue
            )
            DomainStat(
                label: "Blocked",
                value: appState.learnedDomains.filter { $0.classification == .blocked }.count,
                color: .purple
            )
            DomainStat(
                label: "Safe",
                value: appState.learnedDomains.filter { $0.classification == .safe }.count,
                color: .green
            )
            DomainStat(
                label: "DNS Hostile",
                value: appState.learnedDomains.filter { $0.classification == .dnsHostile }.count,
                color: .orange
            )
            DomainStat(
                label: "Today",
                value: appState.domainsLearnedToday,
                color: .mint
            )
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search domains...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Filter
            Menu {
                Button("All") { filterClassification = nil }
                Divider()
                ForEach([DomainClassification.safe, .blocked, .dnsHostile, .unknown], id: \.self) { c in
                    Button(c.displayLabel) { filterClassification = c }
                }
            } label: {
                Label(
                    filterClassification?.displayLabel ?? "All",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
                .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            // Sort
            Menu {
                Button("Most Recent") { sortOrder = .recent }
                Button("Most Hits") { sortOrder = .hits }
                Button("Alphabetical") { sortOrder = .alpha }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    // MARK: - Domain List

    private var domainList: some View {
        List {
            if filteredDomains.isEmpty {
                ContentUnavailableView(
                    "No Domains",
                    systemImage: "globe",
                    description: Text("Learned domains will appear here as FreeNet discovers them.")
                )
            } else {
                ForEach(filteredDomains) { domain in
                    DomainRow(domain: domain)
                        .contextMenu {
                            Menu("Override Classification") {
                                ForEach([DomainClassification.safe, .blocked, .dnsHostile, .unknown], id: \.self) { c in
                                    Button(c.displayLabel) {
                                        overrideClassification(domain: domain, to: c)
                                    }
                                }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Filtering & Sorting

    private var filteredDomains: [DomainRecord] {
        var results = appState.learnedDomains

        // Filter by classification
        if let filter = filterClassification {
            results = results.filter { $0.classification == filter }
        }

        // Filter by search
        if !searchText.isEmpty {
            results = results.filter {
                $0.domain.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Sort
        switch sortOrder {
        case .recent:
            results.sort { $0.learnedAt > $1.learnedAt }
        case .hits:
            results.sort { $0.hitCount > $1.hitCount }
        case .alpha:
            results.sort { $0.domain < $1.domain }
        }

        return results
    }

    // MARK: - Actions

    private func overrideClassification(domain: DomainRecord, to classification: DomainClassification) {
        try? appState.domainStore?.updateClassification(domain: domain.domain, to: classification)
        appState.refreshLearnedDomains()
    }
}

// MARK: - Sort Order

private enum SortOrder {
    case recent, hits, alpha
}

// MARK: - Domain Stat

private struct DomainStat: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Domain Row

private struct DomainRow: View {
    let domain: DomainRecord

    var body: some View {
        HStack(spacing: 12) {
            // Domain
            Text(domain.domain)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Classification badge
            ClassificationBadge(classification: domain.classification)

            // Failure type
            if let failure = domain.failureType {
                Text(failure.shortLabel)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            // Source
            Text(domain.source.shortLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .center)

            // Time
            Text(domain.learnedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 80, alignment: .trailing)

            // Hits
            HStack(spacing: 2) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 8))
                Text("\(domain.hitCount)")
                    .font(.system(.caption2, design: .monospaced))
            }
            .foregroundStyle(.secondary)
            .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Classification Badge

private struct ClassificationBadge: View {
    let classification: DomainClassification

    var body: some View {
        Text(classification.displayLabel)
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(classification.color.opacity(0.15))
            .foregroundStyle(classification.color)
            .clipShape(Capsule())
    }
}

// MARK: - Display Helpers

extension DomainClassification {
    var displayLabel: String {
        switch self {
        case .safe:       return "Safe"
        case .blocked:    return "Blocked"
        case .dnsHostile: return "DNS Hostile"
        case .unknown:    return "Unknown"
        }
    }

    var color: Color {
        switch self {
        case .safe:       return .green
        case .blocked:    return .purple
        case .dnsHostile: return .orange
        case .unknown:    return .gray
        }
    }
}

extension FailureType {
    var shortLabel: String {
        switch self {
        case .connectionReset:    return "RST"
        case .dnsFailure:         return "DNS"
        case .tlsFailure:         return "TLS"
        case .httpForbidden:      return "403"
        case .contentRestriction: return "GEO"
        case .timeout:            return "TMO"
        case .emptyResponse:      return "EMPTY"
        case .dnsHostile:         return "DNSH"
        }
    }
}

extension DomainSource {
    var shortLabel: String {
        switch self {
        case .preSeeded:   return "Seed"
        case .autoLearned: return "Auto"
        case .crowd:       return "Crowd"
        case .userManual:  return "Manual"
        }
    }
}
