import WidgetKit
import SwiftUI

struct TaskEntry: TimelineEntry {
    let date: Date
    let tasks: [TaskItem]
    let totalPending: Int
}

struct TaskItem: Codable {
    let id: String
    let title: String
    let status: Int
    let priority: Int
}

struct Provider: TimelineProvider {
    typealias Entry = TaskEntry

    func placeholder(in context: Context) -> TaskEntry {
        TaskEntry(date: Date(), tasks: [], totalPending: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaskEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaskEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }

    private func loadEntry() -> TaskEntry {
        let defaults = UserDefaults(suiteName: "group.app.lapis.todo")
        let taskCount = defaults?.integer(forKey: "task_count") ?? 0
        let totalPending = defaults?.integer(forKey: "total_pending") ?? 0

        var tasks: [TaskItem] = []
        if let data = defaults?.string(forKey: "tasks_json") {
            if let jsonData = data.data(using: .utf8) {
                tasks = (try? JSONDecoder().decode([TaskItem].self, from: jsonData)) ?? []
            }
        }

        return TaskEntry(date: Date(), tasks: tasks, totalPending: totalPending)
    }
}

struct LapisTaskWidgetEntryView: View {
    var entry: TaskEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Today's Tasks")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if !entry.tasks.isEmpty {
                    Text("\(entry.tasks.count) today")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 4)

            if entry.tasks.isEmpty {
                Text("No tasks due today")
                    .font(.caption)
                    .foregroundColor(.gray)
            } else {
                ForEach(entry.tasks.prefix(5), id: \.id) { task in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(task.status == 1 ? Color.yellow : Color.white)
                            .frame(width: 6, height: 6)
                        Text(task.title)
                            .font(.caption)
                            .foregroundColor(task.status == 1 ? .yellow : .white)
                            .lineLimit(1)
                    }
                }
            }

            if entry.totalPending > 0 {
                Text("\(entry.totalPending) pending")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .padding(.top, 2)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(red: 0.1, green: 0.1, blue: 0.18)
        }
    }
}

@main
struct LapisTaskWidget: Widget {
    let kind: String = "LapisTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LapisTaskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Today's Tasks")
        .description("Shows your tasks due today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}