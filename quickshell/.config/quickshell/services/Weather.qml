pragma Singleton

import QtQuick

QtObject {
    id: root

    // Defaults for Terrey Hills, NSW (as seen in weather.sh)
    property string latitude: "-33.6811"
    property string longitude: "151.2291"
    property string locationName: "Terrey Hills"
    property string unit: "celsius" // "celsius" or "fahrenheit"

    property var currentWeather: null
    property var dailyForecast: null
    property var hourlyForecast: null
    property bool loading: false
    property string error: ""
    
    // derived properties for easy access
    property string temperature: currentWeather ? Math.round(currentWeather.temperature_2m ?? currentWeather.temperature) + "°" : "--"
    property string feelsLike: currentWeather ? Math.round(currentWeather.apparent_temperature) + "°" : "--"
    property string windSpeed: currentWeather ? Math.round(currentWeather.wind_speed_10m) + (unit === "fahrenheit" ? " mph" : " km/h") : "--"
    property string humidity: currentWeather ? Math.round(currentWeather.relative_humidity_2m) + "%" : "--"
    property string precipProb: currentWeather ? Math.round(currentWeather.precipitation_probability ?? 0) + "%" : "--"
    property string uvIndex: currentWeather ? (currentWeather.uv_index ?? 0).toFixed(1) : "--"
    property int weatherCode: currentWeather ? (currentWeather.weather_code ?? currentWeather.weathercode) : -1
    property bool isDay: currentWeather ? currentWeather.is_day === 1 : true

    function getIcon(code, isDay) {
        if (code === 0)
            return isDay ? "☀️" : "🌙";
        if (code >= 1 && code <= 3)
            return isDay ? "⛅" : "☁️";
        if (code >= 45 && code <= 48)
            return "🌫️";
        if (code >= 51 && code <= 67)
            return "🌧️";
        if (code >= 71 && code <= 77)
            return "❄️";
        if (code >= 80 && code <= 82)
            return "🌧️";
        if (code >= 85 && code <= 86)
            return "❄️";
        if (code >= 95 && code <= 99)
            return "⚡";
        return "🌥️";
    }

    function getFontIcon(code, isDay) {
        if (code === 0)
            return isDay ? "\u{f0599}" : "\u{f0594}";
        if (code >= 1 && code <= 3)
            return isDay ? "\u{f0595}" : "\u{f0f31}";
        if (code >= 45 && code <= 48)
            return "\u{f0591}";
        if (code >= 51 && code <= 67)
            return "\u{f0597}";
        if (code >= 71 && code <= 77)
            return "\u{f0598}";
        if (code >= 80 && code <= 82)
            return "\u{f0597}";
        if (code >= 85 && code <= 86)
            return "\u{f0598}";
        if (code >= 95 && code <= 99)
            return "\u{f0593}";
        return "\u{f0590}";
    }

    function getCondition(code) {
        if (code === 0)
            return "Clear";
        if (code === 1)
            return "Mostly Clear";
        if (code === 2)
            return "Partly Cloudy";
        if (code === 3)
            return "Overcast";
        if (code >= 45 && code <= 48)
            return "Fog";
        if (code >= 51 && code <= 55)
            return "Drizzle";
        if (code >= 56 && code <= 57)
            return "Freezing Drizzle";
        if (code >= 61 && code <= 65)
            return "Rain";
        if (code >= 66 && code <= 67)
            return "Freezing Rain";
        if (code >= 71 && code <= 77)
            return "Snow";
        if (code >= 80 && code <= 82)
            return "Showers";
        if (code >= 85 && code <= 86)
            return "Snow Showers";
        if (code >= 95 && code <= 99)
            return "Thunderstorm";
        return "Cloudy";
    }

    property string condition: getCondition(weatherCode)

    property var searchResults: []
    property bool searchLoading: false
    // Guards against out-of-order responses clobbering newer results.
    property int _searchSeq: 0
    property int _fetchSeq: 0

    function searchLocation(query) {
        if (!query || query.length < 2) {
            _searchSeq++;
            searchResults = [];
            return ;
        }
        searchLoading = true;
        const seq = ++_searchSeq;
        var xhr = new XMLHttpRequest();
        var url = "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(query) + "&count=5&language=en&format=json";
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (seq !== _searchSeq) return;
                searchLoading = false;
                if (xhr.status === 200) {
                    try {
                        var json = JSON.parse(xhr.responseText);
                        var results = json.results || [];
                        root.searchResults = results.map(function(item) {
                            item.full_name = item.name + (item.admin1 ? (", " + item.admin1) : "") + (item.country ? (", " + item.country) : "");
                            return item;
                        });
                    } catch (e) {
                    }
                }
            }
        };
        xhr.open("GET", url);
        xhr.send();
    }

    function fetchWeather() {
        if (!latitude || !longitude)
            return ;

        loading = true;
        error = "";
        const seq = ++_fetchSeq;

        var xhr = new XMLHttpRequest();
        var url = "https://api.open-meteo.com/v1/forecast?latitude=" + latitude + "&longitude=" + longitude +
                 "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,precipitation_probability,uv_index" +
                 "&hourly=temperature_2m,weather_code,precipitation_probability" +
                 "&daily=weather_code,temperature_2m_max,temperature_2m_min,uv_index_max,precipitation_probability_max&timezone=auto" +
                 "&temperature_unit=" + unit +
                 "&wind_speed_unit=" + (unit === "fahrenheit" ? "mph" : "kmh");

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (seq !== _fetchSeq) return;
                loading = false;
                if (xhr.status === 200) {
                    try {
                        var json = JSON.parse(xhr.responseText);
                        root.currentWeather = json.current || json.current_weather;
                        root.dailyForecast = json.daily;
                        root.hourlyForecast = json.hourly;
                    } catch (e) {
                        root.error = "Parse Error";
                    }
                } else {
                    root.error = "Fetch Error: " + xhr.status;
                }
            }
        };
        xhr.open("GET", url);
        xhr.send();

        // Optional: Fetch Location Name if not set
        if (!locationName || locationName === "Unknown") {
            var geoXhr = new XMLHttpRequest();
            var geoUrl = "https://nominatim.openstreetmap.org/reverse?lat=" + latitude + "&lon=" + longitude + "&format=json";
            geoXhr.onreadystatechange = function() {
                if (geoXhr.readyState === XMLHttpRequest.DONE) {
                    if (geoXhr.status === 200) {
                        try {
                            var json = JSON.parse(geoXhr.responseText);
                            if (json.address) {
                                var addr = json.address;
                                var name = addr.city || addr.town || addr.village || addr.suburb || addr.municipality || "Unknown Location";
                                if (name && name !== "Unknown Location")
                                    root.locationName = name;
                            }
                        } catch (e) {
                        }
                    }
                }
            };
            geoXhr.open("GET", geoUrl);
            geoXhr.setRequestHeader("User-Agent", "Quickshell-Weather/1.0");
            geoXhr.send();
        }
    }

    onLatitudeChanged: fetchDebounce.restart()
    onLongitudeChanged: fetchDebounce.restart()
    onUnitChanged: fetchDebounce.restart()

    Component.onCompleted: fetchWeather()

    property Timer autoRefreshTimer: Timer {
        id: autoRefreshTimer
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }

    property Timer fetchDebounce: Timer {
        id: fetchDebounce
        interval: 1000
        repeat: false
        onTriggered: root.fetchWeather()
    }
}
