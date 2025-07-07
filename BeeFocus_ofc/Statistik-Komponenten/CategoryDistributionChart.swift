//
//  CategoryDistributionChart.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 15.06.25.
//

import Foundation
import SwiftUI

struct CategoryDistributionChart: View {
    @EnvironmentObject var todoStore: TodoStore
    
    var body: some View {
        VStack(spacing: 10) {
            ForEach(TaskCategory.allCases, id: \.self) { category in
                let totalTodos = max(1, todoStore.todos.count)
                // Hier category.name mit category.rawValue vergleichen
                let categoryCount = todoStore.todos.filter { $0.category?.name == category.rawValue }.count
                let widthFactor = CGFloat(categoryCount) / CGFloat(totalTodos)
                
                HStack {
                    Text(category.rawValue)
                        .frame(width: 100, alignment: .leading)
                    
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(category.color)
                            .frame(width: geometry.size.width * widthFactor)
                    }
                    .frame(height: 20)
                    
                    Text("\(categoryCount)")
                        .frame(width: 40)
                }
            }
        }
    }
}
