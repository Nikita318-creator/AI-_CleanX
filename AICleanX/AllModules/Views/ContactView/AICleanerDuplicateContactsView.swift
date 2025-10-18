import SwiftUI
import CoreData
import Contacts
import ContactsUI

// ИДЕНТИФИЦИРУЕМАЯ ОБЕРТКА ДЛЯ ГРУППЫ
struct ContactGroup: Identifiable {
    let id = UUID()
    let contacts: [CNContact]
}

struct AICleanerDuplicateContactsView: View {
    @ObservedObject var viewModel: AICleanerContactsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDuplicates: Set<String> = []
    @State private var showMergeAlert = false
    @State private var selectedGroup: [CNContact]?
    
    // groupToNavigate - ЛОКАЛЬНОЕ @State, используем $groupToNavigate
    @State private var groupToNavigate: ContactGroup? = nil
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            ZStack {
                LinearGradient(gradient: Gradient(colors: [CMColor.background, CMColor.backgroundSecondary]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    VStack(spacing: 12 * scalingFactor) {
                        HStack {
                            Button(action: { dismiss() }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 24 * scalingFactor, weight: .semibold))
                                    .foregroundColor(CMColor.primary)
                                    .padding(.leading, 8 * scalingFactor)
                            }
                            
                            Spacer()
                            
                            // ✏️ ИСПРАВЛЕНИЕ: "Identity Cleanup" -> "Очистка контактов"
                            Text("Contact Cleanup")
                                .font(.system(size: 24 * scalingFactor, weight: .heavy))
                                .foregroundColor(CMColor.primaryText)
                            
                            Spacer()
                            
                            let selectedCount = selectedDuplicates.count
                            
                            if selectedCount >= 2 {
                                Button(action: {
                                    if let groupToMerge = viewModel.duplicateGroups.first(where: { group in
                                        group.contains(where: { selectedDuplicates.contains($0.identifier) })
                                    }) {
                                        selectedGroup = groupToMerge
                                        showMergeAlert = true
                                    }
                                }) {
                                    // ✏️ ИСПРАВЛЕНИЕ: "Merge" -> "Объединить"
                                    Text("Merge (\(selectedCount))")
                                        .font(.system(size: 16 * scalingFactor, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10 * scalingFactor)
                                        .padding(.vertical, 6 * scalingFactor)
                                        .background(viewModel.isPerformingMerge ? Color.gray : CMColor.error)
                                        .cornerRadius(8 * scalingFactor)
                                }
                                .disabled(viewModel.isPerformingMerge)
                            } else {
                                Button(action: {
                                    Task { await viewModel.loadSystemContacts() }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 20 * scalingFactor, weight: .semibold))
                                        .foregroundColor(CMColor.primary)
                                        .padding(.trailing, 8 * scalingFactor)
                                }
                                .disabled(viewModel.isLoading || viewModel.isPerformingMerge)
                            }
                        }
                        .padding(.top, 16 * scalingFactor)
                        .padding(.horizontal, 8 * scalingFactor)

                        if !viewModel.duplicateGroups.isEmpty {
                            let totalDuplicates = viewModel.duplicateGroups.flatMap { $0 }.count
                            // ✏️ ИСПРАВЛЕНИЕ: "We've detected... that can be combined."
                            Text("We found \(viewModel.duplicateGroups.count) groups with \(totalDuplicates) contacts that seem to be duplicates and can be merged.")
                                .font(.system(size: 15 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.primaryText.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24 * scalingFactor)
                        }
                    }
                    .padding(.bottom, 24 * scalingFactor)
                    
                    if viewModel.duplicateGroups.isEmpty {
                        noDuplicatesFoundView(scalingFactor: scalingFactor)
                    } else {
                        ScrollView {
                            let columns = [
                                GridItem(.flexible(), spacing: 16 * scalingFactor),
                                GridItem(.flexible())
                            ]
                            
                            LazyVGrid(columns: columns, spacing: 16 * scalingFactor) {
                                ForEach(Array(viewModel.duplicateGroups.enumerated()), id: \.offset) { index, group in
                                    squareDuplicateCard(group: group, scalingFactor: scalingFactor)
                                }
                            }
                            .padding(.horizontal, 16 * scalingFactor)
                            .padding(.vertical, 24 * scalingFactor)
                        }
                    }
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(item: $groupToNavigate) { identifiableGroup in
            DuplicateGroupDetailView(viewModel: viewModel, group: identifiableGroup.contacts)
                .onDisappear {
                    Task { await viewModel.loadSystemContacts() }
                }
        }
        // ✏️ ИСПРАВЛЕНИЕ: "Confirm Consolidation" -> "Подтвердите объединение"
        .alert("Confirm Merge", isPresented: $showMergeAlert) {
            // ✏️ ИСПРАВЛЕНИЕ: "Merge Now" -> "Объединить сейчас"
            Button("Merge Now", role: .destructive) {
                if let group = selectedGroup {
                    mergeSelectedContactsInGroup(group)
                }
                selectedGroup = nil
            }
            // ✏️ ИСПРАВЛЕНИЕ: "Keep Separate" -> "Оставить как есть"
            Button("Keep Separate", role: .cancel) {
                selectedDuplicates.removeAll()
            }
        } message: {
            // ✏️ ИСПРАВЛЕНИЕ: "Are you certain you want to consolidate these duplicate entries? This action cannot be reversed."
            Text("Are you sure you want to merge these duplicate entries? This action cannot be undone.")
        }
        // ✏️ ИСПРАВЛЕНИЕ: "Process Complete" -> "Готово"
        .alert("Success", isPresented: $viewModel.showMergeSuccess) {
            Button("OK") {
                viewModel.mergeSuccessMessage = nil
            }
        } message: {
            Text(viewModel.mergeSuccessMessage ?? "Contacts successfully merged!")
        }
    }
    
    private func toggleSelectAll(for group: [CNContact]?) {
        guard let group = group else { return }
        
        let groupIds = group.map { $0.identifier }
        let selectedInGroup = groupIds.filter { selectedDuplicates.contains($0) }.count
        
        if selectedInGroup < group.count {
            groupIds.forEach { selectedDuplicates.insert($0) }
        } else {
            groupIds.forEach { selectedDuplicates.remove($0) }
        }
    }
    
    private func mergeSelectedContactsInGroup(_ group: [CNContact]) {
        let selectedInGroup = group.filter { selectedDuplicates.contains($0.identifier) }
        let selectedIds = Set(selectedInGroup.map { $0.identifier })
        
        guard selectedInGroup.count >= 2 else {
            // ✏️ ИСПРАВЛЕНИЕ: "Please choose at least 2 contacts for consolidation."
            viewModel.errorMessage = "Please choose at least 2 contacts to merge."
            return
        }
        
        Task {
            viewModel.isPerformingMerge = true
            
            let success = await viewModel.mergeSelectedContacts(selectedIds: selectedIds)
            
            await MainActor.run {
                viewModel.isPerformingMerge = false
                
                if success {
                    selectedIds.forEach { selectedDuplicates.remove($0) }
                    
                    // ✏️ ИСПРАВЛЕНИЕ: "The selected \(selectedInGroup.count) contacts were merged into one master entry."
                    viewModel.mergeSuccessMessage = "The selected \(selectedInGroup.count) contacts have been merged into one entry."
                    viewModel.showMergeSuccess = true
                    
                    Task { await viewModel.loadSystemContacts() }
                }
            }
        }
    }

    // MARK: - Square Contact Card

    private func squareDuplicateCard(group: [CNContact], scalingFactor: CGFloat) -> some View {
        let primaryContact = group.first!
        let selectedCount = group.filter { selectedDuplicates.contains($0.identifier) }.count
        let allSelected = selectedCount == group.count
        
        return GeometryReader { buttonGeometry in
            VStack(alignment: .leading, spacing: 10 * scalingFactor) {
                
                HStack {
                    ZStack {
                        Circle()
                            .fill(CMColor.primary.opacity(0.8))
                            .frame(width: 44 * scalingFactor, height: 44 * scalingFactor)
                            
                        Text(String(primaryContact.givenName.prefix(1).uppercased()))
                            .font(.system(size: 20 * scalingFactor, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        toggleSelectAll(for: group)
                    }) {
                        Image(systemName: allSelected ? "checkmark.circle.fill" : (selectedCount > 0 ? "circle.fill" : "circle"))
                            .font(.system(size: 24 * scalingFactor))
                            .foregroundColor(allSelected ? CMColor.success : (selectedCount > 0 ? CMColor.primary.opacity(0.7) : CMColor.border))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // ✏️ ИСПРАВЛЕНИЕ: "Potential Match" -> "Возможный дубликат"
                Text("Possible Duplicate")
                    .font(.system(size: 12 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.error)
                    .padding(.horizontal, 6 * scalingFactor)
                    .padding(.vertical, 2 * scalingFactor)
                    .background(CMColor.error.opacity(0.1))
                    .cornerRadius(4 * scalingFactor)
                
                Text("\(primaryContact.givenName) \(primaryContact.familyName)")
                    .font(.system(size: 18 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                    .lineLimit(1)
                
                // ✏️ ИСПРАВЛЕНИЕ: "Entries" -> "Записи"
                Text("\(group.count) Copies")
                    .font(.system(size: 14 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
            }
            .padding(16 * scalingFactor)
            .frame(width: buttonGeometry.size.width, height: buttonGeometry.size.width)
            .background(
                RoundedRectangle(cornerRadius: 16 * scalingFactor)
                    .fill(CMColor.surface)
                    .shadow(color: .black.opacity(0.1), radius: 6 * scalingFactor, x: 0, y: 3 * scalingFactor)
            )
            .onTapGesture {
                groupToNavigate = ContactGroup(contacts: group)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - No Duplicates View
    
    private func noDuplicatesFoundView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            Spacer()
            Image(systemName: "sparkles.square.fill")
                .font(.system(size: 60 * scalingFactor, weight: .bold))
                .foregroundColor(CMColor.success)
            
            VStack(spacing: 8 * scalingFactor) {
                // ✏️ ИСПРАВЛЕНИЕ: "Zero Contact Clutter!" -> "Контакты чисты! 🎉"
                Text("Contacts are Clean! 🎉")
                    .font(.system(size: 24 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                // ✏️ ИСПРАВЛЕНИЕ: "All your contacts appear to be unique. No consolidation needed right now."
                Text("All your contacts appear to be unique. No merging or cleanup is required at the moment.")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32 * scalingFactor)
            }
            Spacer()
        }
        .padding(.horizontal, 20 * scalingFactor)
    }
}

struct DuplicateGroupDetailView: View {
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var viewModel: AICleanerContactsViewModel
    
    let group: [CNContact]
    
    @State private var masterContactIdentifier: String
    
    init(viewModel: AICleanerContactsViewModel, group: [CNContact]) {
        self.viewModel = viewModel
        self.group = group
        // Устанавливаем в качестве основного контакта тот, у которого больше данных
        let initialMaster = group.max { c1, c2 in
            viewModel.calculateContactCompleteness(c1) < viewModel.calculateContactCompleteness(c2)
        }
        _masterContactIdentifier = State(initialValue: initialMaster?.identifier ?? "")
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                List {
                    // ✏️ ИСПРАВЛЕНИЕ: "Choose the Master Contact" -> "Выберите основной контакт"
                    Section(header: Text("Choose the Primary Contact").font(.headline)) {
                        ForEach(group, id: \.identifier) { contact in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(contact.givenName) \(contact.familyName)")
                                        .font(.headline)
                                    // Показываем, что контакт имеет больше данных
                                    if masterContactIdentifier == contact.identifier {
                                        Text("Selected to keep all data")
                                            .font(.caption)
                                            .foregroundColor(CMColor.success)
                                    }
                                    Text(contact.phoneNumbers.first?.value.stringValue ?? "No Phone Number")
                                        .font(.subheadline)
                                        .foregroundColor(Color.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: contact.identifier == masterContactIdentifier ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(CMColor.primary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                masterContactIdentifier = contact.identifier
                            }
                        }
                    }
                    
                    // ✏️ ИСПРАВЛЕНИЕ: "Data to be Consolidated" -> "Что произойдет при объединении"
                    Section(header: Text("How the Merge Works")) {
                        // ✏️ ИСПРАВЛЕНИЕ: "All unique data... merged into the chosen Master Contact."
                        Text("All unique names, phone numbers, and emails from the other \(group.count - 1) contacts will be safely added to the selected Primary Contact. The duplicates will then be deleted.")
                            .font(.caption)
                            .foregroundColor(Color.gray)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                mergeButton
            }
            // ✏️ ИСПРАВЛЕНИЕ: "Consolidate Group" -> "Объединение группы"
            .navigationTitle("Merge Contacts (\(group.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private var mergeButton: some View {
        Button(action: {
            Task {
                await performConsolidation()
            }
        }) {
            // ✏️ ИСПРАВЛЕНИЕ: "Consolidating..." / "Consolidate to Master Contact"
            Text(viewModel.isPerformingMerge ? "Merging..." : "Merge into Primary Contact")
                .font(.system(size: 18, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundColor(.white)
                .background(viewModel.isPerformingMerge ? Color.gray : CMColor.success)
                .cornerRadius(14)
        }
        .padding([.horizontal, .bottom], 16)
        .disabled(viewModel.isPerformingMerge)
    }
    
    private func performConsolidation() async {
        guard let masterContact = group.first(where: { $0.identifier == masterContactIdentifier }) else { return }
        
        viewModel.isPerformingMerge = true
        
        let success = await viewModel.mergeContactGroup(group, masterContact: masterContact)
        
        await MainActor.run {
            viewModel.isPerformingMerge = false

            if success {
                // ✏️ ИСПРАВЛЕНИЕ: Сообщение об успешном объединении
                viewModel.mergeSuccessMessage = "Successfully merged \(group.count) contacts into \(masterContact.givenName) \(masterContact.familyName)."
                viewModel.showMergeSuccess = true
                dismiss()
            }
        }
    }
}
