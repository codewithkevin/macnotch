import SwiftUI

/// The third pager page: a 2×2 grid of configurable widgets.
/// Right-click a slot to change what it shows.
struct DashboardPage: View {
    @ObservedObject var viewModel: NotchViewModel
    @ObservedObject var battery: BatteryMonitor
    @StateObject private var store = DashboardStore()
    @StateObject private var weather = WeatherService()

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<DashboardStore.slotCount, id: \.self) { index in
                DashboardSlot(kind: store.slots[index]) { newKind in
                    store.setSlot(index, to: newKind)
                } content: {
                    widget(for: store.slots[index])
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { weather.start() }
    }

    @ViewBuilder
    private func widget(for kind: DashboardWidgetKind) -> some View {
        switch kind {
        case .dayProgress: DayProgressWidget(now: viewModel.now)
        case .quote:       QuoteWidget(now: viewModel.now)
        case .weather:     WeatherWidget(weather: weather)
        case .shelf:       ShelfWidget(viewModel: viewModel)
        case .battery:     BatteryWidget(battery: battery)
        case .empty:       EmptyView()
        }
    }
}

// MARK: - Slot chrome

private struct DashboardSlot<Content: View>: View {
    let kind: DashboardWidgetKind
    let onChange: (DashboardWidgetKind) -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .contextMenu {
                ForEach(DashboardWidgetKind.allCases) { option in
                    Button {
                        onChange(option)
                    } label: {
                        Label(option.title, systemImage: option.symbol)
                    }
                }
            }
    }
}

// MARK: - Widgets

private struct DayProgressWidget: View {
    let now: Date

    private var fraction: Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return now.timeIntervalSince(start) / end.timeIntervalSince(start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Day", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 0)
            Text("\(Int(fraction * 100))%")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            ProgressView(value: fraction)
                .tint(.white.opacity(0.85))
        }
    }
}

private struct QuoteWidget: View {
    let now: Date

    var body: some View {
        let quote = Quotes.current(for: now)
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "quote.opening")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            Text(quote.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(3)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text("— \(quote.author)")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        }
    }
}

private struct WeatherWidget: View {
    @ObservedObject var weather: WeatherService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let c = weather.conditions {
                HStack(spacing: 6) {
                    Image(systemName: c.symbol)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                    Text("\(Int(c.temperature.rounded()))°")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text(c.summary)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Text("H \(Int(c.high.rounded()))°")
                    Text("L \(Int(c.low.rounded()))°")
                }
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.45))
                if !c.place.isEmpty {
                    Text(c.place).font(.system(size: 9)).foregroundStyle(.white.opacity(0.35)).lineLimit(1)
                }
            } else {
                Label("Weather", systemImage: "cloud.sun")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 0)
                Text(weather.lastError ?? "Loading…")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShelfWidget: View {
    @ObservedObject var viewModel: NotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Shelf", systemImage: "tray.full")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            if viewModel.shelfItems.isEmpty {
                Spacer(minLength: 0)
                Text("Drop files onto the notch")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                Spacer(minLength: 0)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.shelfItems, id: \.self) { url in
                            ShelfChip(url: url) { viewModel.removeFromShelf(url) }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct BatteryWidget: View {
    @ObservedObject var battery: BatteryMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Battery", systemImage: "battery.100")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 0)
            if let s = battery.state {
                HStack(spacing: 6) {
                    Image(systemName: s.symbolName).font(.system(size: 16))
                    Text("\(s.percent)%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(s.isCharging ? .green : (s.percent <= 20 ? .red : .white))
            } else {
                Text("No battery").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}
