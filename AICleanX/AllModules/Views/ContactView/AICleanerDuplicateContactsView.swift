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
                    // Completely new Header
                    VStack(spacing: 12 * scalingFactor) {
                        HStack {
                            Button(action: {
                                dismiss()
                            }) {
                                HStack(spacing: 8 * scalingFactor) {
                                    Image(systemName: "arrow.backward.circle.fill")
                                        .font(.system(size: 20 * scalingFactor, weight: .bold))
                                        .foregroundColor(CMColor.primary)
                                    
                                    Text("Go Back")
                                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                                        .foregroundColor(CMColor.primary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    await viewModel.loadSystemContacts()
                                }
                            }) {
                                HStack(spacing: 8 * scalingFactor) {
                                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                        .font(.system(size: 20 * scalingFactor, weight: .bold))
                                        .foregroundColor(CMColor.primary)
                                    
                                    Text("Refresh")
                                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                                        .foregroundColor(CMColor.primary)
                                }
                            }
                        }
                        .padding(.horizontal, 20 * scalingFactor)
                        .padding(.top, 16 * scalingFactor)
                        
                        Text("Duplicate Contacts Found")
                            .font(.system(size: 28 * scalingFactor, weight: .heavy))
                            .foregroundColor(CMColor.primaryText)
                        
                        if !viewModel.duplicateGroups.isEmpty {
                            let totalDuplicates = viewModel.duplicateGroups.flatMap { $0 }.count
                            Text("You have \(viewModel.duplicateGroups.count) groups with \(totalDuplicates) duplicate contacts.")
                                .font(.system(size: 14 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.primaryText.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24 * scalingFactor)
                        }
                    }
                    .padding(.bottom, 24 * scalingFactor)
                    
                    if viewModel.duplicateGroups.isEmpty {
                        VStack(spacing: 16 * scalingFactor) {
                            Spacer()
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 60 * scalingFactor, weight: .bold))
                                .foregroundColor(CMColor.success)
                            Text("No Duplicates Found")
                                .font(.system(size: 24 * scalingFactor, weight: .bold))
                                .foregroundColor(CMColor.primaryText)
                            Text("Your contacts are clean! Great job!")
                                .font(.system(size: 16 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.secondaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 20 * scalingFactor)
                    } else {
                        ScrollView {
                            VStack(spacing: 32 * scalingFactor) {
                                ForEach(Array(viewModel.duplicateGroups.enumerated()), id: \.offset) { index, group in
                                    // Используем новый, исправленный дублированный раздел
                                    duplicateGroupSection(group: group, groupIndex: index, scalingFactor: scalingFactor, isFirstGroup: index == 0)
                                }
                            }
                            .padding(.vertical, 24 * scalingFactor)
                        }
                    }
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .alert("Merge Confirmation", isPresented: $showMergeAlert) {
            Button("Yes, Merge", role: .destructive) {
                // Исправлено: теперь вызываем mergeSelectedContactsInGroup
                if let group = selectedGroup {
                    mergeSelectedContactsInGroup(group)
                }
            }
            Button("No, Cancel", role: .cancel) {
                // Опционально: можно очистить selectedDuplicates при отмене, если нужно
                selectedDuplicates.removeAll()
            }
        } message: {
            Text("Are you sure you want to merge these duplicate contacts? This action is permanent.")
        }
        .alert("Merge Complete", isPresented: $showMergeSuccess) {
            Button("Done") {
                mergeSuccessMessage = nil
            }
        } message: {
            Text(mergeSuccessMessage ?? "Contacts successfully merged!")
        }
    }
    
    // MARK: - Helper Methods
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
        let areAllSelected = groupIds.allSatisfy { selectedDuplicates.contains($0) }
        
        if areAllSelected {
            groupIds.forEach { selectedDuplicates.remove($0) }
        } else {
            groupIds.forEach { selectedDuplicates.insert($0) }
        }
    }
    
    private func mergeSelectedContactsInGroup(_ group: [CNContact]) {
        let selectedInGroup = group.filter { selectedDuplicates.contains($0.identifier) }
        let selectedIds = Set(selectedInGroup.map { $0.identifier })
        
        guard selectedInGroup.count >= 2 else {
            viewModel.errorMessage = "Please select at least 2 contacts to merge"
            return
        }
        
        Task {
            isPerformingMerge = true
            
            let success = await viewModel.mergeContactGroup(group, selectedIds: selectedIds)
            
            await MainActor.run {
                isPerformingMerge = false
                
                if success {
                    selectedIds.forEach { selectedDuplicates.remove($0) }
                    
                    // Show success message
                    mergeSuccessMessage = "Successfully merged \(selectedInGroup.count) contacts"
                    showMergeSuccess = true
                    
                    Task {
                        await viewModel.loadSystemContacts()
                    }
                }
            }
        }
    }
    
    private func duplicateGroupSection(group: [CNContact], groupIndex: Int, scalingFactor: CGFloat, isFirstGroup: Bool) -> some View {
        let firstContact = group.first!
        let selectedInGroup = group.filter { selectedDuplicates.contains($0.identifier) }.count
        
        return VStack(spacing: 16 * scalingFactor) {
            VStack(spacing: 12 * scalingFactor) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(isFirstGroup ? CMColor.primary : CMColor.secondary)
                            .frame(width: 40 * scalingFactor, height: 40 * scalingFactor)
                        
                        Text(String(firstContact.givenName.prefix(1).uppercased()))
                            .font(.system(size: 18 * scalingFactor, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                        HStack {
                            Text(isFirstGroup ? "Duplicates" : "Group \(groupIndex + 1)")
                                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                                .foregroundColor(CMColor.primaryText)
                            
                            Text("\(group.count)")
                                .font(.system(size: 12 * scalingFactor, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6 * scalingFactor)
                                .padding(.vertical, 2 * scalingFactor)
                                .background(CMColor.error)
                                .cornerRadius(8 * scalingFactor)
                        }
                        
                        let fullName = "\(firstContact.givenName) \(firstContact.familyName)"
                        Text(fullName.count > 25 ? String(fullName.prefix(22)) + "..." : fullName)
                            .font(.system(size: 15 * scalingFactor, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                        
                        if let phoneNumber = firstContact.phoneNumbers.first?.value.stringValue {
                            Text(phoneNumber)
                                .font(.system(size: 15 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    if selectedInGroup > 0 {
                        VStack {
                            Text("\(selectedInGroup)/\(group.count)")
                                .font(.system(size: 12 * scalingFactor, weight: .semibold))
                                .foregroundColor(CMColor.primary)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16 * scalingFactor))
                                .foregroundColor(CMColor.primary)
                        }
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
                .padding(.horizontal, 16 * scalingFactor)
                .padding(.vertical, 12 * scalingFactor)
                .background(
                    RoundedRectangle(cornerRadius: 12 * scalingFactor)
                        .fill(CMColor.surface)
                        .shadow(color: .black.opacity(0.05), radius: 2 * scalingFactor, x: 0, y: 1 * scalingFactor)
                )
                .onTapGesture {
                    // При нажатии на заголовок группы, переключаем выбор всех контактов
                    toggleSelectAll(for: group)
                }
                
                // Заголовок "Select contacts to merge" и кнопка "Select all"
                HStack {
                    Text("Select contacts to merge")
                        .font(.system(size: 15 * scalingFactor, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                    
                    Spacer()
                    
                    Button(action: {
                        toggleSelectAll(for: group)
                    }) {
                        Text(selectedInGroup == group.count ? "Deselect all" : "Select all")
                            .font(.system(size: 15 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.primary)
                    }
                }
                .padding(.horizontal, 16 * scalingFactor)
                
                // Список дубликатов
                VStack(spacing: 8 * scalingFactor) {
                    ForEach(Array(group.enumerated()), id: \.element.identifier) { index, contact in
                        enhancedDuplicateContactCard(
                            contact: contact,
                            isSelected: selectedDuplicates.contains(contact.identifier),
                            isPrimary: index == 0,
                            scalingFactor: scalingFactor
                        )
                    }
                }
                .padding(.horizontal, 16 * scalingFactor)
                
                // Кнопка для объединения
                if selectedInGroup >= 2 {
                    Button(action: {
                        // Исправлено: теперь при нажатии на кнопку сразу вызываем метод
                        mergeSelectedContactsInGroup(group)
                    }) {
                        HStack {
                            if isPerformingMerge {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.triangle.merge")
                                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                            }
                            
                            Text(isPerformingMerge ? "Merging..." : "Merge \(selectedInGroup) contacts")
                                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48 * scalingFactor)
                        .background(isPerformingMerge ? CMColor.primary.opacity(0.7) : CMColor.primary)
                        .cornerRadius(12 * scalingFactor)
                    }
                    .disabled(isPerformingMerge)
                    .animation(.easeInOut(duration: 0.2), value: isPerformingMerge)
                    .padding(.horizontal, 16 * scalingFactor)
                    .padding(.top, 8 * scalingFactor)
                }
            }
            .padding(.vertical, 8 * scalingFactor)
        }
    }
        
    private func enhancedDuplicateContactCard(contact: CNContact, isSelected: Bool, isPrimary: Bool, scalingFactor: CGFloat) -> some View {
        Button(action: {
            toggleSelection(for: contact.identifier)
        }) {
            HStack(spacing: 12 * scalingFactor) {
                // Selection checkbox
                ZStack {
                    Circle()
                        .stroke(isSelected ? CMColor.primary : CMColor.border, lineWidth: 2)
                        .frame(width: 24 * scalingFactor, height: 24 * scalingFactor)
                    
                    if isSelected {
                        Circle()
                            .fill(CMColor.primary)
                            .frame(width: 16 * scalingFactor, height: 16 * scalingFactor)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 10 * scalingFactor, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    HStack {
                        Text("\(contact.givenName) \(contact.familyName)")
                            .font(.system(size: 16 * scalingFactor, weight: isPrimary ? .semibold : .regular))
                            .foregroundColor(CMColor.primaryText)
                        
                        if isPrimary {
                            Text("RECOMMENDED")
                                .font(.system(size: 10 * scalingFactor, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6 * scalingFactor)
                                .padding(.vertical, 2 * scalingFactor)
                                .background(CMColor.success)
                                .cornerRadius(4 * scalingFactor)
                        }
                    }
                    
                    if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
                        Text(phoneNumber)
                            .font(.system(size: 14 * scalingFactor, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                    }
                    
                    if let email = contact.emailAddresses.first?.value as? String {
                        Text(email)
                            .font(.system(size: 14 * scalingFactor, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                    }
                    
                    HStack(spacing: 8 * scalingFactor) {
                        if contact.phoneNumbers.count > 1 {
                            Label("\(contact.phoneNumbers.count)", systemImage: "phone")
                                .font(.system(size: 12 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                        }
                        
                        if !contact.emailAddresses.isEmpty {
                            Label("\(contact.emailAddresses.count)", systemImage: "envelope")
                                .font(.system(size: 12 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                        }
                        
                        if !contact.organizationName.isEmpty {
                            Label(contact.organizationName, systemImage: "building")
                                .font(.system(size: 12 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 12 * scalingFactor)
            .background(
                RoundedRectangle(cornerRadius: 8 * scalingFactor)
                    .fill(isSelected ? CMColor.primary.opacity(0.05) : CMColor.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8 * scalingFactor)
                            .stroke(isSelected ? CMColor.primary : CMColor.border, lineWidth: 1)
                    )
            )
        }
    }
    
    private func noDuplicatesFoundView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48 * scalingFactor))
                .foregroundColor(CMColor.success)
            
            VStack(spacing: 8 * scalingFactor) {
                Text("No Duplicates Found")
                    .font(.system(size: 20 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("All your contacts are unique. Great job keeping your contacts organized!")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32 * scalingFactor)
            }
        }
        .padding(.vertical, 48 * scalingFactor)
    }
}
