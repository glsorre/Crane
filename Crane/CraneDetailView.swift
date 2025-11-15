//
//  CraneDetailView.swift
//  Crane
//
//  Created by Giuseppe Lucio Sorrentino on 06/11/25.
//

import ContainerClient
import ContainerizationError
import ContainerNetworkService
import ContainerPlugin
import Containerization
import ContainerizationOS
import Combine
import Observation
import SwiftUI

struct CraneDetailView: View {
    @Bindable var viewModel: CraneViewModel
    var id: String
    
    var body: some View {
        ContainerDetailsView(viewModel: viewModel, id: id)
            .onChange(of: id) { _, _ in
                viewModel.currentHandle = 0
            }
    }
}
