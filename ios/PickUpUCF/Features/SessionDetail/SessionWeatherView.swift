import SwiftUI

struct SessionWeatherView: View {
    @Environment(\.colorScheme) private var colorScheme
    let weather: WeatherSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(weather.displayLine)
                .font(AppFont.body(.semibold))
                .foregroundStyle(AppColor.textPrimary(colorScheme))
            Text("Weather data: [Open-Meteo](https://open-meteo.com/) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Rounded to whole values.")
                .font(AppFont.caption())
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .tint(AppColor.accent(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
