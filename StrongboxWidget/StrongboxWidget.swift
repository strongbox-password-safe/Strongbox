import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }
    
    func getSnapshot(in context: Context, completion: @escaping @Sendable (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SimpleEntry>) -> Void) {
        let currentDate = Date()
        let entry = SimpleEntry(date: currentDate)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct StrongboxWidgetEntryView : View {
    private static let deeplinkURL: URL = URL(string: "strongbox-widget-deeplink://2fa")!
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallContent
            case .systemMedium:
                smallContent
            case .systemLarge:
                largeContent
            case .systemExtraLarge:
                largeContent
            case .systemExtraLargePortrait:
                largeContent
            case .accessoryCorner:
                smallContent
            case .accessoryCircular:
                smallContent
            case .accessoryRectangular:
                largeContent
            case .accessoryInline:
                smallContent
            @unknown default:
                largeContent
            }
        }
        .widgetURL(Self.deeplinkURL)
    }
    
    private var largeContent: some View {
        VStack(alignment: .leading) {
            Text("2FA Quick Access")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Strongbox")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var smallContent: some View {
        Text("2FA")
    }
}

struct StrongboxWidget: Widget {
    let kind: String = "StrongboxWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StrongboxWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

#Preview(as: .accessoryRectangular) {
    StrongboxWidget()
} timeline: {
    SimpleEntry(date: .now)
    SimpleEntry(date: .now)
}
