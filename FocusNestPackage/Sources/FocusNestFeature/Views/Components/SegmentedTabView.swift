import SwiftUI

public struct SegmentedTabView<T: Hashable & CaseIterable>: View where T.AllCases: RandomAccessCollection, T: CustomStringConvertible {
    @Binding var selection: T

    public init(selection: Binding<T>) {
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(T.allCases), id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selection = option }
                } label: {
                    Text(option.description)
                        .font(Theme.headlineFont)
                        .foregroundStyle(selection == option ? .white : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.spacingS)
                        .background { if selection == option { Capsule().fill(Theme.focusColor) } }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.backgroundSecondary)
        .clipShape(Capsule())
    }
}

public enum TaskTab: String, CaseIterable, CustomStringConvertible {
    case todo = "To Do"
    case done = "Done"
    public var description: String { rawValue }
}

public enum ProgressTab: String, CaseIterable, CustomStringConvertible {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    public var description: String { rawValue }
}
