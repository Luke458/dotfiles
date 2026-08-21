pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

Item {
    id: root

    readonly property bool ready: Weather.currentWeather !== null && Weather.error === ""
    readonly property color accent: {
        if (Weather.weatherCode === 0) return Theme.weatherClear;
        if (Weather.weatherCode >= 45 && Weather.weatherCode <= 48) return Theme.weatherFog;
        if (Weather.weatherCode >= 51 && Weather.weatherCode <= 82) return Theme.weatherRain;
        if (Weather.weatherCode >= 71 && Weather.weatherCode <= 86) return Theme.weatherSnow;
        if (Weather.weatherCode >= 95) return Theme.yellow;
        return Theme.selBg;
    }
    readonly property int horizontalPadding: Theme.spacingContent
    readonly property int topPadding: Theme.spacingPage
    readonly property int bottomPadding: Theme.spacingContent
    implicitWidth: 480
    implicitHeight: Math.min(650, mainLayout.implicitHeight + topPadding + bottomPadding)

    component WeatherTile: Rectangle {
        radius: Theme.radiusPanel
        color: Theme.transparent
        border.color: Theme.transparent
        border.width: 0
    }

    component WeatherText: Text {
        color: Theme.fg
        font.family: Theme.fontMono
    }

    component SectionHeading: WeatherText {
        color: Theme.selFg
        font.pixelSize: Theme.fontSizeLabel
        font.bold: true
        Layout.fillWidth: true
    }

    component MetricTile: WeatherTile {
        id: metricTile

        property string label
        property string value
        property color valueColor: Theme.selFg

        Layout.fillWidth: true
        Layout.preferredHeight: 66

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.spacingMicro

            WeatherText {
                text: metricTile.label
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                opacity: Theme.opacitySecondaryLow
                Layout.alignment: Qt.AlignHCenter
            }

            WeatherText {
                text: metricTile.value
                color: metricTile.valueColor
                font.pixelSize: Theme.fontSizeBanner
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    component HourlyTile: WeatherTile {
        id: hourlyTile

        property string timeLabel
        property string icon
        property string temperature
        property string precip
        property color accentColor: Theme.selFg

        Layout.fillWidth: true
        Layout.preferredHeight: 94

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingSmall
            spacing: Theme.spacingTiny

            WeatherText {
                text: hourlyTile.timeLabel
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                opacity: Theme.opacitySecondary
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: hourlyTile.icon
                font.pixelSize: Theme.fontSizeValueMedium
                Layout.alignment: Qt.AlignHCenter
            }

            WeatherText {
                text: hourlyTile.temperature
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeHeadingLarge
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            WeatherText {
                text: hourlyTile.precip
                color: hourlyTile.accentColor
                font.pixelSize: Theme.fontSizeBody
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    component DayForecastRow: WeatherTile {
        id: dayRow

        property string dayName
        property string dateLabel
        property string icon
        property string condition
        property string temperatureRange
        property string precip
        property color accentColor: Theme.selFg
        property var minTemp: null
        property var maxTemp: null
        property real lowLimit: 0
        property real highLimit: 1

        Layout.fillWidth: true
        Layout.preferredHeight: 50

        function barX(width) {
            if (minTemp === null) return 0;
            const span = Math.max(1, highLimit - lowLimit);
            const rawX = ((minTemp - lowLimit) / span) * width;
            return Math.max(0, Math.min(Math.max(0, width - 8), rawX));
        }

        function barWidth(width) {
            if (maxTemp === null || minTemp === null) return 8;
            const span = Math.max(1, highLimit - lowLimit);
            const x = barX(width);
            const rawWidth = ((maxTemp - minTemp) / span) * width;
            return Math.max(8, Math.min(width - x, rawWidth));
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingSection
            anchors.rightMargin: Theme.spacingSection
            spacing: Theme.spacingMedium

            ColumnLayout {
                spacing: 0
                Layout.preferredWidth: 62

                WeatherText {
                    text: dayRow.dayName
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeTitle
                    font.bold: true
                }

                WeatherText {
                    text: dayRow.dateLabel
                    font.pixelSize: Theme.fontSizeBody
                    opacity: Theme.opacityMedium
                }
            }

            Text {
                text: dayRow.icon
                font.pixelSize: Theme.fontSizeValueSmall
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignHCenter
            }

            WeatherText {
                text: dayRow.condition
                font.pixelSize: Theme.fontSizeBar
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Rectangle {
                id: rangeTrack

                Layout.preferredWidth: 72
                Layout.minimumWidth: 72
                Layout.preferredHeight: 5
                radius: Theme.radiusCompact
                color: Theme.border
                opacity: Theme.opacitySecondaryHigh

                Rectangle {
                    x: dayRow.barX(rangeTrack.width)
                    width: Math.min(rangeTrack.width - x, dayRow.barWidth(rangeTrack.width))
                    height: rangeTrack.height
                    radius: rangeTrack.radius
                    color: dayRow.accentColor
                }
            }

            WeatherText {
                text: dayRow.temperatureRange
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                Layout.preferredWidth: 76
                Layout.minimumWidth: 76
                horizontalAlignment: Text.AlignRight
            }

            WeatherText {
                text: dayRow.precip
                color: dayRow.accentColor
                font.pixelSize: Theme.fontSizeLabel
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    function degrees(value) {
        return value !== null && value !== undefined ? value + "°" : "--";
    }

    function dailyRange(index, separator) {
        return degrees(dailyMax(index)) + separator + degrees(dailyMin(index));
    }

    function getDayName(index) {
        if (!Weather.dailyForecast || !Weather.dailyForecast.time || index >= Weather.dailyForecast.time.length) return "";
        const date = new Date(Weather.dailyForecast.time[index]);
        const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        return index === 0 ? "Today" : days[date.getDay()];
    }

    function getDayDate(index) {
        if (!Weather.dailyForecast || !Weather.dailyForecast.time || index >= Weather.dailyForecast.time.length) return "";
        const date = new Date(Weather.dailyForecast.time[index]);
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        return months[date.getMonth()] + " " + date.getDate();
    }

    function dailyCode(index) {
        return Weather.dailyForecast && Weather.dailyForecast.weather_code ? Weather.dailyForecast.weather_code[index] : -1;
    }

    function dailyMax(index) {
        return Weather.dailyForecast && Weather.dailyForecast.temperature_2m_max ? Math.round(Weather.dailyForecast.temperature_2m_max[index]) : null;
    }

    function dailyMin(index) {
        return Weather.dailyForecast && Weather.dailyForecast.temperature_2m_min ? Math.round(Weather.dailyForecast.temperature_2m_min[index]) : null;
    }

    function dailyPrecip(index) {
        if (!Weather.dailyForecast || !Weather.dailyForecast.precipitation_probability_max) return "--";
        return Math.round(Weather.dailyForecast.precipitation_probability_max[index]) + "%";
    }

    // Computed once per forecast refresh instead of rescanning the whole
    // hourly/daily arrays from every delegate binding.
    readonly property int _hourStart: {
        const forecast = Weather.hourlyForecast;
        if (!forecast || !forecast.time || forecast.time.length === 0) return -1;
        const now = new Date();
        for (let i = 0; i < forecast.time.length; i++) {
            if (new Date(forecast.time[i]) >= now) return i;
        }
        return 0;
    }
    readonly property real _dayLowLimit: {
        const mins = Weather.dailyForecast ? Weather.dailyForecast.temperature_2m_min : null;
        if (!mins) return 0;
        let low = 1000;
        for (let i = 0; i < mins.length; i++)
            low = Math.min(low, mins[i]);
        return low;
    }
    readonly property real _dayHighLimit: {
        const maxs = Weather.dailyForecast ? Weather.dailyForecast.temperature_2m_max : null;
        if (!maxs) return 1;
        let high = -1000;
        for (let i = 0; i < maxs.length; i++)
            high = Math.max(high, maxs[i]);
        return high;
    }

    function hourIndex(offset) {
        if (_hourStart < 0 || !Weather.hourlyForecast || !Weather.hourlyForecast.time) return -1;
        return Math.min(_hourStart + offset, Weather.hourlyForecast.time.length - 1);
    }

    function hourLabel(hourlyIndex, offset) {
        if (hourlyIndex < 0 || !Weather.hourlyForecast || !Weather.hourlyForecast.time) return "--";
        if (offset === 0) return "NOW";
        const date = new Date(Weather.hourlyForecast.time[hourlyIndex]);
        const hour = date.getHours();
        const displayHour = hour % 12 || 12;
        return displayHour + (hour >= 12 ? "PM" : "AM");
    }

    function hourlyTemp(hourlyIndex) {
        if (hourlyIndex < 0 || !Weather.hourlyForecast || !Weather.hourlyForecast.temperature_2m) return "--";
        return Math.round(Weather.hourlyForecast.temperature_2m[hourlyIndex]) + "°";
    }

    function hourlyPrecip(hourlyIndex) {
        if (hourlyIndex < 0 || !Weather.hourlyForecast || !Weather.hourlyForecast.precipitation_probability) return "--";
        return Math.round(Weather.hourlyForecast.precipitation_probability[hourlyIndex]) + "%";
    }

    function hourlyIcon(hourlyIndex) {
        if (hourlyIndex < 0 || !Weather.hourlyForecast || !Weather.hourlyForecast.weather_code) return Weather.getIcon(Weather.weatherCode, Weather.isDay);
        return Weather.getIcon(Weather.hourlyForecast.weather_code[hourlyIndex], true);
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            id: mainLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: root.horizontalPadding
            anchors.rightMargin: root.horizontalPadding
            anchors.topMargin: root.topPadding
            spacing: Theme.spacingContent
            visible: root.ready

            WeatherTile {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                radius: Theme.radiusHandle

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXSmall

                    WeatherText {
                        text: Weather.locationName.toUpperCase()
                        color: Theme.selFg
                        font.pixelSize: Theme.fontSizeTitle
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    RowLayout {
                        spacing: Theme.spacingMedium
                        Layout.alignment: Qt.AlignHCenter

                        Text {
                            text: Weather.getIcon(Weather.weatherCode, Weather.isDay)
                            font.pixelSize: Theme.fontSizeHero
                            Layout.alignment: Qt.AlignVCenter
                        }

                        WeatherText {
                            text: Weather.temperature
                            color: Theme.selFg
                            font.pixelSize: Theme.fontSizeHero
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    WeatherText {
                        text: Weather.condition + "  •  " + root.dailyRange(0, " / ")
                        color: root.accent
                        font.pixelSize: Theme.fontSizeBar
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 5
                columnSpacing: 9
                rowSpacing: 9

                Repeater {
                    model: [
                        { label: "FEELS", value: Weather.feelsLike, color: Theme.selFg },
                        { label: "RAIN", value: Weather.precipProb, color: root.accent },
                        { label: "HUMID", value: Weather.humidity, color: Theme.selFg },
                        { label: "WIND", value: Weather.windSpeed, color: Theme.selFg },
                        { label: "UV", value: Weather.uvIndex, color: Number(Weather.uvIndex) >= 7 ? Theme.yellow : Theme.selFg }
                    ]

                    delegate: MetricTile {
                        required property var modelData
                        label: modelData.label
                        value: modelData.value
                        valueColor: modelData.color
                    }
                }
            }

            SectionHeading {
                text: "NEXT HOURS"
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingIntermediate

                Repeater {
                    model: Weather.hourlyForecast ? 8 : 0

                    delegate: HourlyTile {
                        required property int index
                        readonly property int hIndex: root.hourIndex(index)

                        timeLabel: root.hourLabel(hIndex, index)
                        icon: root.hourlyIcon(hIndex)
                        temperature: root.hourlyTemp(hIndex)
                        precip: "☂ " + root.hourlyPrecip(hIndex)
                        accentColor: root.accent
                    }
                }
            }

            SectionHeading {
                text: "7 DAY FORECAST"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingIntermediate

                Repeater {
                    model: Weather.dailyForecast ? Math.min(7, Weather.dailyForecast.time.length) : 0

                    delegate: DayForecastRow {
                        required property int index
                        dayName: root.getDayName(index).toUpperCase()
                        dateLabel: root.getDayDate(index)
                        icon: Weather.getIcon(root.dailyCode(index), true)
                        condition: Weather.getCondition(root.dailyCode(index))
                        temperatureRange: root.dailyRange(index, " / ")
                        precip: "☂ " + root.dailyPrecip(index)
                        accentColor: root.accent
                        minTemp: root.dailyMin(index)
                        maxTemp: root.dailyMax(index)
                        lowLimit: root._dayLowLimit
                        highLimit: root._dayHighLimit
                    }
                }
            }

            Item { Layout.preferredHeight: 4 }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.spacingMedium
        visible: Weather.loading || Weather.error !== ""

        WeatherText {
            text: Weather.loading ? "LOADING..." : "ERROR"
            font.pixelSize: Theme.fontSizeTitle
            Layout.alignment: Qt.AlignHCenter
        }

        WeatherText {
            text: Weather.error
            color: Theme.red
            font.pixelSize: Theme.fontSizeLabel
            visible: Weather.error !== ""
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
