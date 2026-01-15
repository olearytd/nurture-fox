import SwiftUI
import SwiftData

struct EditEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var event: BabyEvent
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    DatePicker("Entry Time", selection: $event.timestamp, in: ...Date())
                }
                
                if event.type == "FEED" {
                    Section("Amount") {
                        HStack {
                            TextField("Amount", value: $event.amount, format: .number)
                                .keyboardType(.decimalPad)
                            
                            Picker("Unit", selection: $event.subtype) {
                                Text("oz").tag("oz")
                                Text("ml").tag("ml")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                            // Standardized Math: Conversion logic when user toggles unit
                            .onChange(of: event.subtype) { oldUnit, newUnit in
                                if newUnit == "ml" && oldUnit == "oz" {
                                    event.amount *= 30
                                } else if newUnit == "oz" && oldUnit == "ml" {
                                    event.amount /= 30
                                }
                            }
                        }
                    }
                } else {
                    Section("Type") {
                        Picker("Diaper Type", selection: $event.subtype) {
                            Text("Pee").tag("Pee")
                            Text("Poop").tag("Poop")
                            Text("Both").tag("Both")
                        }
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
