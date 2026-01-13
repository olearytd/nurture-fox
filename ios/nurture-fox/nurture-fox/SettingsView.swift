//
//  SettingsView.swift
//  nurture-fox
//
//  Created by Tim OLeary on 1/9/26.
//


import SwiftUI

struct SettingsView: View {
    // SharedPreferences equivalents in iOS [Image of SwiftUI AppStorage vs Android SharedPreferences]
    @AppStorage("babyName") private var babyName: String = "Nurture Fox"
    @AppStorage("babyBirthday") private var babyBirthday: Double = Date().timeIntervalSince1970
    @AppStorage("themePreference") private var themePreference: Int = 0 // 0: System, 1: Light, 2: Dark
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Child Profile")) {
                    TextField("Baby Name", text: $babyName)
                    
                    DatePicker("Birthday", selection: Binding(
                        get: { Date(timeIntervalSince1970: babyBirthday) },
                        set: { babyBirthday = $0.timeIntervalSince1970 }
                    ), displayedComponents: .date)
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme Mode", selection: $themePreference) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.navigationLink) // Classic iOS chevron style
                }
                
                Section(header: Text("Legal")) {
                    Link(destination: URL(string: "https://github.com/olearytd/nurture-fox/blob/main/PRIVACY.md")!) {
                        HStack {
                            Label("Privacy Policy", systemImage: "lock.shield")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}