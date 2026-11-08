import SwiftUI

/// Digital Crown picker from V0 to V14, plus Benchmarks only.
struct GradePickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router

    @State private var grade = AppSettings.defaultGrade
    @State private var benchmarksOnly = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 8) {
            Picker("Grade", selection: $grade) {
                ForEach(Array(Grades.range), id: \.self) { vGrade in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Grades.vName(vGrade))
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                        Text(Grades.fontRange(vGrade))
                            .font(.footnote.weight(.semibold))
                    }
                    .tag(vGrade)
                    .accessibilityLabel("\(Grades.vName(vGrade)), Font \(Grades.fontRange(vGrade))")
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .focusEffectDisabled()
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.blue, lineWidth: 2.5))
            .frame(maxHeight: .infinity)

            Toggle("Benchmarks only", isOn: $benchmarksOnly)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))

            Button {
                settings.lastGrade = grade
                settings.benchmarksOnly = benchmarksOnly
                router.pop()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: LightControls.height)
                    .background(Theme.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Grade")
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            grade = settings.lastGrade
            benchmarksOnly = settings.benchmarksOnly
        }
    }
}
