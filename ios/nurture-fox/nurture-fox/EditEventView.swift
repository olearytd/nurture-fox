import SwiftUI
import SwiftData
import CoreData

struct EditEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: BabyEventEntity

    private var timestampBinding: Binding<Date> {
        Binding(
            get: { event.timestamp ?? Date() },
            set: { event.timestamp = $0 }
        )
    }

    private var subtypeBinding: Binding<String> {
        Binding(
            get: { event.subtype ?? "oz" },
            set: { event.subtype = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Time") {
                    DatePicker("Entry Time", selection: timestampBinding, in: ...Date())
                }

                if (event.type ?? "FEED") == "FEED" {
                    Section("Amount") {
                        HStack {
                            TextField("Amount", value: $event.amount, format: .number)
                                .keyboardType(.decimalPad)

                            Picker("Unit", selection: subtypeBinding) {
                                Text("oz").tag("oz")
                                Text("ml").tag("ml")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                            .onChange(of: event.subtype) { oldUnit, newUnit in
                                let oldU = oldUnit ?? "oz"
                                let newU = newUnit ?? "oz"
                                if newU == "ml" && oldU == "oz" {
                                    event.amount *= 30
                                } else if newU == "oz" && oldU == "ml" {
                                    event.amount /= 30
                                }
                            }
                        }
                    }
                } else {
                    Section("Type") {
                        Picker("Diaper Type", selection: subtypeBinding) {
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
                    Button("Done") {
                        do {
                            try viewContext.save()
                        } catch {
                            print("Error saving event: \(error)")
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
