import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct NowPlayingWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let podcastName: String
    let imageUrl: String
    let isPlaying: Bool
}

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingWidgetEntry {
        NowPlayingWidgetEntry(
            date: Date(),
            title: "Not Playing",
            podcastName: "Sonde",
            imageUrl: "",
            isPlaying: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingWidgetEntry) -> Void) {
        let entry = readEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingWidgetEntry>) -> Void) {
        let entry = readEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func readEntry() -> NowPlayingWidgetEntry {
        let defaults = UserDefaults.standard
        return NowPlayingWidgetEntry(
            date: Date(),
            title: defaults.string(forKey: "now_playing_title") ?? "Not Playing",
            podcastName: defaults.string(forKey: "now_playing_podcast") ?? "Sonde",
            imageUrl: defaults.string(forKey: "now_playing_image") ?? "",
            isPlaying: defaults.bool(forKey: "now_playing_is_playing")
        )
    }
}

// MARK: - Widget View

struct NowPlayingWidgetEntryView: View {
    var entry: NowPlayingWidgetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallNowPlayingView(entry: entry)
        case .systemMedium:
            MediumNowPlayingView(entry: entry)
        default:
            SmallNowPlayingView(entry: entry)
        }
    }
}

struct SmallNowPlayingView: View {
    let entry: NowPlayingWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Spacer()
                Image(systemName: entry.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(entry.title)
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(entry.podcastName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct MediumNowPlayingView: View {
    let entry: NowPlayingWidgetEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NOW PLAYING")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                Text(entry.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(entry.podcastName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()
            }

            Spacer()

            Image(systemName: entry.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.title)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Widget Definition

struct NowPlayingWidget: Widget {
    let kind: String = "now_playing_widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NowPlayingProvider()) { entry in
            NowPlayingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("See what's currently playing in Sonde.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
