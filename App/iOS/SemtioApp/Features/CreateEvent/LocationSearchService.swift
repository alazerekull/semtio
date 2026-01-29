//
//  LocationSearchService.swift
//  SemtioApp
//
//  Copyright © 2026 Oğuzhan Çankaya ve Fikir Creative. All rights reserved.
//

import Foundation
import MapKit
import Combine

class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var completions: [MKLocalSearchCompletion] = []
    
    private var completer: MKLocalSearchCompleter
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
        
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                if query.isEmpty {
                    self?.completions = []
                } else {
                    self?.completer.queryFragment = query
                }
            }
            .store(in: &cancellables)
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completions = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Handle error if needed
        print("Search error: \(error.localizedDescription)")
    }
    
    func search(for completion: MKLocalSearchCompletion) async throws -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems.first
    }
    
    func search(query: String, region: MKCoordinateRegion?) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region = region {
             request.region = region
        }
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems
    }
}
