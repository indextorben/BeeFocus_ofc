import Foundation
import SwiftUI
import Charts

class StatisticsData {
    var todayData: [ChartDataPoint] = []
    var weekData: [ChartDataPoint] = []
    var monthData: [ChartDataPoint] = []
    var yearData: [ChartDataPoint] = []
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let category: String
        let value: Double
        let date: Date
    }
}

class StatisticsChart: ObservableObject {
    @Published var selectedTimeRange: TimeRange = .week
    @Published var statisticsData = StatisticsData()
    
    enum TimeRange: String, CaseIterable {
        case today = "Heute"
        case week = "Woche"
        case month = "Monat"
        case year = "Jahr"
    }
    
    func loadData(from todoStore: TodoStore) {
        // Heutige Daten
        statisticsData.todayData = [
            StatisticsData.ChartDataPoint(category: "Arbeit", value: 8, date: Date()),
            StatisticsData.ChartDataPoint(category: "Persönlich", value: 3, date: Date()),
            StatisticsData.ChartDataPoint(category: "Einkaufen", value: 2, date: Date())
        ]
        
        let calendar = Calendar.current
        let now = Date()
        
        // Wochen-Daten
        statisticsData.weekData = (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            return StatisticsData.ChartDataPoint(
                category: "Tag \(7 - dayOffset)",
                value: Double.random(in: 1...10),
                date: date
            )
        }.reversed()
        
        // Monats-Daten
        statisticsData.monthData = (0..<4).map { weekOffset in
            let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now)!
            return StatisticsData.ChartDataPoint(
                category: "Woche \(4 - weekOffset)",
                value: Double.random(in: 20...50),
                date: date
            )
        }.reversed()
        
        // Jahres-Daten
        statisticsData.yearData = (0..<12).map { monthOffset in
            let date = calendar.date(byAdding: .month, value: -monthOffset, to: now)!
            return StatisticsData.ChartDataPoint(
                category: calendar.monthSymbols[calendar.component(.month, from: date) - 1],
                value: Double.random(in: 50...200),
                date: date
            )
        }.reversed()
    }
    
    func currentData() -> [StatisticsData.ChartDataPoint] {
        switch selectedTimeRange {
        case .today:
            return statisticsData.todayData
        case .week:
            return statisticsData.weekData
        case .month:
            return statisticsData.monthData
        case .year:
            return statisticsData.yearData
        }
    }
}

struct StatisticsChartView: View {
    @EnvironmentObject var todoStore: TodoStore
    @StateObject var statsChart = StatisticsChart()
    @Namespace private var animationNamespace
    
    var body: some View {
        VStack(spacing: 20) {
            timeRangePicker
            
            VStack(alignment: .leading) {
                Text(statsChart.selectedTimeRange.rawValue)
                    .font(.title2.bold())
                    .padding(.horizontal)
                
                Chart(statsChart.currentData()) { dataPoint in
                    BarMark(
                        x: .value("Kategorie", dataPoint.category),
                        y: .value("Wert", dataPoint.value)
                    )
                    .foregroundStyle(by: .value("Kategorie", dataPoint.category))
                    .cornerRadius(4)
                }
                .frame(height: 200)
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color(UIColor.secondarySystemBackground)))
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
        .onAppear {
            statsChart.loadData(from: todoStore)
        }
    }
    
    private var timeRangePicker: some View {
        HStack(spacing: 15) {
            ForEach(StatisticsChart.TimeRange.allCases, id: \.self) { range in
                Text(range.rawValue)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background(
                        ZStack {
                            if statsChart.selectedTimeRange == range {
                                Capsule()
                                    .fill(Color.blue)
                                    .matchedGeometryEffect(id: "timeRange", in: animationNamespace)
                            }
                        }
                    )
                    .foregroundColor(statsChart.selectedTimeRange == range ? .white : .primary)
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            statsChart.selectedTimeRange = range
                        }
                    }
            }
        }
        .padding(5)
        .background(
            Capsule()
                .fill(Color(UIColor.systemGray5))
        )
        .padding(.horizontal)
    }
}

struct StatisticsDataPoint: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
    let date: Date
}
