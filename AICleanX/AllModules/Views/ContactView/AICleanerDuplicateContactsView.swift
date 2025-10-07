import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerDuplicateContactsView: View {
    @ObservedObject var viewModel: AICleanerContactsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedDuplicates: Set<String> = []
    @State private var showMergeAlert = false
    @State private var isPerformingMerge = false
    @State private var mergeSuccessMessage: String?
    @State private var showMergeSuccess = false
    @State private var selectedGroup: [CNContact]?

    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            ZStack {
                LinearGradient(gradient: Gradient(colors: [CMColor.background, CMColor.backgroundSecondary]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // --- Header: Classic Back Button and Title ---
                    VStack(spacing: 12 * scalingFactor) {
                        HStack {
                            // CLASSIC BACK BUTTON (Chevron)
                            Button(action: {
                                dismiss()
                            }) {
                                Image(systemName: "chevron.left") // Classic iOS back arrow
                                    .font(.system(size: 24 * scalingFactor, weight: .semibold))
                                    .foregroundColor(CMColor.primary)
                                    .padding(.leading, 8 * scalingFactor)
                            }
                            
                            Spacer()
                            
                            // Screen Title (Updated text)
                            Text("Identity Cleanup")
                                .font(.system(size: 24 * scalingFactor, weight: .heavy))
                                .foregroundColor(CMColor.primaryText)
                            
                            Spacer()
                            
                            // Refresh Button
                            Button(action: {
                                Task {
                                    await viewModel.loadSystemContacts()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                                    .foregroundColor(CMColor.primary)
                                    .padding(.trailing, 8 * scalingFactor)
                            }
                            .disabled(viewModel.isLoading || isPerformingMerge)
                        }
                        .padding(.top, 16 * scalingFactor)
                        .padding(.horizontal, 8 * scalingFactor)

                        // Subtitle/Info (Updated text)
                        if !viewModel.duplicateGroups.isEmpty {
                            let totalDuplicates = viewModel.duplicateGroups.flatMap { $0 }.count
                            Text("We've detected \(viewModel.duplicateGroups.count) groups with \(totalDuplicates) similar contacts that can be combined.")
                                .font(.system(size: 15 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.primaryText.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24 * scalingFactor)
                        }
                    }
                    .padding(.bottom, 24 * scalingFactor)
                    // ---------------------------------------------
                    
                    if viewModel.duplicateGroups.isEmpty {
                        noDuplicatesFoundView(scalingFactor: scalingFactor)
                    } else {
                        ScrollView {
                            // --- LazyVGrid for Square Cells (2 per row) ---
                            let columns = [
                                GridItem(.flexible(), spacing: 16 * scalingFactor),
                                GridItem(.flexible())
                            ]
                            
                            LazyVGrid(columns: columns, spacing: 16 * scalingFactor) {
                                ForEach(Array(viewModel.duplicateGroups.enumerated()), id: \.offset) { index, group in
                                    // Используем новую квадратную карточку
                                    squareDuplicateCard(group: group, groupIndex: index, scalingFactor: scalingFactor)
                                }
                            }
                            // ---------------------------------------------
                            .padding(.horizontal, 16 * scalingFactor)
                            .padding(.vertical, 24 * scalingFactor)
                        }
                    }
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Confirm Consolidation", isPresented: $showMergeAlert) { // Updated text
            Button("Merge Now", role: .destructive) { // Updated text
                if let group = selectedGroup {
                    mergeSelectedContactsInGroup(group)
                }
            }
            Button("Keep Separate", role: .cancel) { // Updated text
                selectedDuplicates.removeAll()
            }
        } message: {
            Text("Are you certain you want to consolidate these duplicate entries? This action cannot be reversed.") // Updated text
        }
        .alert("Process Complete", isPresented: $showMergeSuccess) { // Updated text
            Button("OK") { // Updated text
                mergeSuccessMessage = nil
            }
        } message: {
            Text(mergeSuccessMessage ?? "Contacts successfully unified!") // Updated text
        }
    }
    
    // MARK: - Core Logic
    
    private func toggleSelection(for id: String) {
        if selectedDuplicates.contains(id) {
            selectedDuplicates.remove(id)
        } else {
            selectedDuplicates.insert(id)
        }
    }
    
    private func toggleSelectAll(for group: [CNContact]?) {
        guard let group = group else { return }
        
        let groupIds = group.map { $0.identifier }
        let selectedInGroup = groupIds.filter { selectedDuplicates.contains($0) }.count
        
        // Select all if not all are selected, otherwise deselect all
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
            viewModel.errorMessage = "Please choose at least 2 contacts for consolidation." // Updated text
            return
        }
        
        Task {
            isPerformingMerge = true
            
            let success = await viewModel.mergeContactGroup(group, selectedIds: selectedIds)
            
            await MainActor.run {
                isPerformingMerge = false
                
                if success {
                    selectedIds.forEach { selectedDuplicates.remove($0) }
                    
                    // Show success message (Updated text)
                    mergeSuccessMessage = "The selected \(selectedInGroup.count) contacts were merged into one master entry."
                    showMergeSuccess = true
                    
                    Task {
                        await viewModel.loadSystemContacts()
                    }
                }
            }
        }
    }

    // MARK: - Square Contact Card
    
    private func squareDuplicateCard(group: [CNContact], groupIndex: Int, scalingFactor: CGFloat) -> some View {
        let primaryContact = group.first! // Use the first as the representative
        let selectedCount = group.filter { selectedDuplicates.contains($0.identifier) }.count
        let allSelected = selectedCount == group.count
        
        return Button(action: {
            // Toggle selection for all contacts in this group
            toggleSelectAll(for: group)
        }) {
            GeometryReader { buttonGeometry in
                VStack(alignment: .leading, spacing: 10 * scalingFactor) {
                    
                    // 1. Icon / Initial
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
                        
                        // Selection Status
                        Image(systemName: allSelected ? "checkmark.circle.fill" : (selectedCount > 0 ? "circle.fill" : "circle"))
                            .font(.system(size: 24 * scalingFactor))
                            .foregroundColor(allSelected ? CMColor.success : (selectedCount > 0 ? CMColor.primary.opacity(0.7) : CMColor.border))
                    }
                    
                    Spacer()
                    
                    // 2. Main Title (Updated text)
                    Text("Potential Match")
                        .font(.system(size: 12 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.error)
                        .padding(.horizontal, 6 * scalingFactor)
                        .padding(.vertical, 2 * scalingFactor)
                        .background(CMColor.error.opacity(0.1))
                        .cornerRadius(4 * scalingFactor)
                    
                    // 3. Name & Count (Updated text)
                    Text("\(primaryContact.givenName) \(primaryContact.familyName)")
                        .font(.system(size: 18 * scalingFactor, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                        .lineLimit(1)
                    
                    Text("\(group.count) Entries")
                        .font(.system(size: 14 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                }
                .padding(16 * scalingFactor)
                // --- CORE: Setting height equal to width for a square shape ---
                .frame(width: buttonGeometry.size.width, height: buttonGeometry.size.width)
                // -------------------------------------------------------------
                .background(
                    RoundedRectangle(cornerRadius: 16 * scalingFactor)
                        .fill(CMColor.surface)
                        .shadow(color: .black.opacity(0.1), radius: 6 * scalingFactor, x: 0, y: 3 * scalingFactor)
                )
            }
            .aspectRatio(1, contentMode: .fit) // Ensures the button respects the square layout in the grid
        }
    }
    
    // MARK: - No Duplicates View
    
    private func noDuplicatesFoundView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            Spacer()
            Image(systemName: "sparkles.square.fill") // Updated icon
                .font(.system(size: 60 * scalingFactor, weight: .bold))
                .foregroundColor(CMColor.success)
            
            VStack(spacing: 8 * scalingFactor) {
                Text("Zero Contact Clutter! 🎉") // Updated text
                    .font(.system(size: 24 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("All your contacts appear to be unique. No consolidation needed right now.") // Updated text
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
