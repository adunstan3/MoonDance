import SwiftUI

/// Digital Crown picker for your height (4′0″ to 7′6″). It sets the size of the
/// climber drawn beside the hold pictures, to help judge the distance between
/// holds. Reached from Settings or by tapping the climber.
struct HeightPickerView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 8) {
            Picker("Height", selection: $settings.climberHeight) {
                ForEach(Array(AppSettings.heightRange), id: \.self) { inches in
                    Text(AppSettings.heightText(inches))
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .tag(inches)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .focusEffectDisabled()
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.blue, lineWidth: 2.5))
            .frame(maxHeight: .infinity)
            .accessibilityIdentifier("heightPicker")

            Text("\(AppSettings.centimetres(settings.climberHeight)) cm · sizes the climber beside the hold pictures")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .navigationTitle("Your height")
    }
}
