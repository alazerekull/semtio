//
//  CreateEventSheet.swift
//  SemtioApp
//
//  Created for Events V2 Feature.
//

import SwiftUI
import MapKit

struct CreateEventSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var userStore: UserStore
    
    // We can reuse the existing Feature if it's modular,
    // otherwise we build a simplified one.
    // The requirement was "basic create; district, title, time, visibility, location".
    // Since we have `CreateEventScreen.swift` which does this well, we can wrap it.
    // However, if we want a cleaner V2 sheet specific style:
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var startDate: Date = Date()
    @State private var visibility: EventVisibility = .public
    @State private var selectedDistrict: String?
    
    // Simplification: Reuse CreateEventScreen content via wrapping or reimplementing essential form
    // For expediency and consistency with the "Production Grade" requirement which usually implies using existing robust components:
    // I represents `CreateEventSheet` as a wrapper around the complex logic (Location picking etc).
    
    var body: some View {
        // Reusing the robust screen we already have but wrapping for sheet presentation checks
        CreateEventScreen(eventStore: eventStore, userStore: userStore)
    }
}
