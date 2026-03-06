import SwiftUI

struct PromptTemplateView: View {
    let onSelect: (PromptTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var customTemplates: [PromptTemplate] = []
    @State private var showCreateSheet = false
    @State private var newTemplateName = ""
    @State private var newTemplatePrompt = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Built-in") {
                    ForEach(PromptTemplate.builtIn) { template in
                        Button {
                            onSelect(template)
                            dismiss()
                        } label: {
                            Label(template.name, systemImage: template.icon)
                        }
                    }
                }

                Section("Custom") {
                    if customTemplates.isEmpty {
                        Text("No custom templates yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(customTemplates) { template in
                            Button {
                                onSelect(template)
                                dismiss()
                            } label: {
                                Label(template.name, systemImage: template.icon)
                            }
                        }
                        .onDelete { indexSet in
                            customTemplates.remove(atOffsets: indexSet)
                            saveCustomTemplates()
                        }
                    }

                    Button {
                        showCreateSheet = true
                    } label: {
                        Label("Create Template", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { loadCustomTemplates() }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    Form {
                        TextField("Template Name", text: $newTemplateName)
                        Section("Prompt") {
                            TextEditor(text: $newTemplatePrompt)
                                .frame(minHeight: 100)
                        }
                    }
                    .navigationTitle("New Template")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                newTemplateName = ""
                                newTemplatePrompt = ""
                                showCreateSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                let template = PromptTemplate(
                                    name: newTemplateName,
                                    icon: "text.badge.star",
                                    prompt: newTemplatePrompt
                                )
                                customTemplates.append(template)
                                saveCustomTemplates()
                                newTemplateName = ""
                                newTemplatePrompt = ""
                                showCreateSheet = false
                            }
                            .disabled(newTemplateName.isEmpty || newTemplatePrompt.isEmpty)
                        }
                    }
                }
            }
        }
    }

    private func saveCustomTemplates() {
        if let data = try? JSONEncoder().encode(customTemplates) {
            UserDefaults.standard.set(data, forKey: "custom_templates")
        }
    }

    private func loadCustomTemplates() {
        if let data = UserDefaults.standard.data(forKey: "custom_templates"),
           let templates = try? JSONDecoder().decode([PromptTemplate].self, from: data) {
            customTemplates = templates
        }
    }
}
