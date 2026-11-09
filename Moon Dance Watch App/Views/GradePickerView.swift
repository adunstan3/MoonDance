import SwiftUI

/// Digital Crown picker from V4 to V14, plus Benchmarks only. Changes apply as
/// soon as they're made; the back arrow returns to the list.
struct GradePickerView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 10) {
            Picker("Grade", selection: $settings.lastGrade) {
                ForEach(Array(Grades.range), id: \.self) { vGrade in
                    Text(Grades.bucketName(vGrade, scale: settings.gradeScale))
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .tag(vGrade)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .focusEffectDisabled()
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.blue, lineWidth: 2.5))
            .frame(maxHeight: .infinity)

            Toggle("Benchmarks only", isOn: $settings.benchmarksOnly)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        }
        .navigationTitle("Grade")
    }
}
