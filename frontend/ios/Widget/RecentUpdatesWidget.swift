import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct RecentUpdatesWidgetEntry: TimelineEntry {
    let date: Date
    let count: Int
    let episodes: [EpisodeInfo]
}

struct EpisodeInfo {
    let title: String
    let podcastName: String
}

struct RecentUpdatesProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentUpdatesWidgetEntry {
        RecentUpdatesWidgetEntry(
            date: Date(),
            count: 0,
            episodes: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentUpdatesWidgetEntry) -> Void) {
        let entry = readEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentUpdatesWidgetEntry>) -> Void) {
        let entry = readEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func readEntry() -> RecentUpdatesWidgetEntry {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: "recent_count")

        var episodes: [EpisodeInfo] = []
        for i in 0..<min(count, 3) {
            let title = defaults.string(forKey: "recent_\(i)_title") ?? ""
            let podcast = defaults.string(forKey: "recent_\(i)_podcast") ?? ""
            if !title.isEmpty {
                episodes.append(EpisodeInfo(title: title, podcastName: podcast))
            }
        }

        return RecentUpdatesWidgetEntry(
            date: Date(),
            count: count,
            episodes: episodes
        )
    }
}

// MARK: - Widget View

struct RecentUpdatesWidgetEntryView: View {
    var entry: RecentUpdatesWidgetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallRecentUpdatesView(entry: entry)
        case .systemMedium:
            MediumRecentUpdatesView(entry: entry)
        default:
            SmallRecentUpdatesView(entry: entry)
        }
    }
}

struct SmallRecentUpdatesView: View {
    let entry: RecentUpdatesWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "podcast")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("New Episodes")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if entry.count > 0 {
                    Text("\(entry.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                }
            }

            Spacer()

            if entry.episodes.isEmpty {
                Text("No new episodes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.episodes[0].title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(entry.episodes[0].podcastName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct MediumRecentUpdatesView: View {
    let entry: RecentUpdatesWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "podcast")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("New Episodes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if entry.count > 0 {
                    Text("\(entry.count) new")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            if entry.episodes.isEmpty {
                Text("No new episodes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(entry.episodes.prefix(3).enumerated()), id: \.offset) { index, episode in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(episode.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(episode.podcastName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)

                    if index < min(entry.episodes.count, 3) - 1 {
                        Divider()
                    }
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Widget Definition

struct RecentUpdatesWidget: Widget {
    let kind: String = "recent_updates_widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentUpdatesProvider()) { entry in
            RecentUpdatesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Recent Updates")
        .description("See recent podcast episodes in Sonde.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
