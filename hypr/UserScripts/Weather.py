#!/usr/bin/env python3
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
# weather using Open-Meteo API

import json
import os

import requests


WEATHER_MODE_FILE = os.path.expanduser("~/.config/hypr/.weather_location_mode")


WEATHER_CODE_MAP = {
    0: ("󰖙", "Clear sky"),
    1: ("󰖕", "Mainly clear"),
    2: ("󰖐", "Partly cloudy"),
    3: ("", "Overcast"),
    45: ("", "Fog"),
    48: ("", "Depositing rime fog"),
    51: ("", "Light drizzle"),
    53: ("", "Moderate drizzle"),
    55: ("", "Dense drizzle"),
    56: ("", "Light freezing drizzle"),
    57: ("", "Dense freezing drizzle"),
    61: ("", "Slight rain"),
    63: ("", "Moderate rain"),
    65: ("", "Heavy rain"),
    66: ("", "Light freezing rain"),
    67: ("", "Heavy freezing rain"),
    71: ("", "Slight snow fall"),
    73: ("", "Moderate snow fall"),
    75: ("", "Heavy snow fall"),
    77: ("", "Snow grains"),
    80: ("", "Slight rain showers"),
    81: ("", "Moderate rain showers"),
    82: ("", "Violent rain showers"),
    85: ("", "Slight snow showers"),
    86: ("", "Heavy snow showers"),
    95: ("", "Thunderstorm"),
    96: ("", "Thunderstorm with slight hail"),
    99: ("", "Thunderstorm with heavy hail"),
}


def get_current_location() -> tuple[float, float, str]:
    response = requests.get("https://ipinfo.io/json", timeout=10)
    response.raise_for_status()
    data = response.json()
    lat, lon = data["loc"].split(",")
    label = data.get("city") or data.get("region") or "Current location"
    return float(lat), float(lon), label


def get_location_mode() -> str:
    env_mode = os.environ.get("WEATHER_LOCATION_MODE", "").strip().lower()
    if env_mode in {"current", "hcm"}:
        return env_mode

    try:
        with open(WEATHER_MODE_FILE, "r") as file:
            file_mode = file.read().strip().lower()
            if file_mode in {"current", "hcm"}:
                return file_mode
    except FileNotFoundError:
        pass

    return "current"


def get_location() -> tuple[float, float, str]:
    mode = get_location_mode()

    if mode == "hcm":
        return 10.8231, 106.6297, "Ho Chi Minh City"

    return get_current_location()


def get_weather(lat: float, lon: float) -> dict:
    params = {
        "latitude": lat,
        "longitude": lon,
        "current": [
            "temperature_2m",
            "relative_humidity_2m",
            "apparent_temperature",
            "weather_code",
            "wind_speed_10m",
        ],
        "daily": [
            "weather_code",
            "temperature_2m_max",
            "temperature_2m_min",
            "precipitation_probability_max",
            "uv_index_max",
        ],
        "hourly": ["visibility"],
        "timezone": "auto",
        "forecast_days": 1,
    }
    response = requests.get(
        "https://api.open-meteo.com/v1/forecast",
        params=params,
        timeout=10,
    )
    response.raise_for_status()
    return response.json()


def code_to_icon_and_status(code: int) -> tuple[str, str]:
    return WEATHER_CODE_MAP.get(code, ("", "Unknown"))


def fmt_temp(value: float) -> str:
    return f"{round(value)}°C"


def fmt_number(value: float, suffix: str = "") -> str:
    rounded = round(value)
    return f"{rounded}{suffix}"


def main() -> None:
    try:
        latitude, longitude, location_label = get_location()
        data = get_weather(latitude, longitude)

        current = data["current"]
        daily = data["daily"]
        hourly = data.get("hourly", {})

        weather_code = int(current["weather_code"])
        icon, status = code_to_icon_and_status(weather_code)

        temp = fmt_temp(current["temperature_2m"])
        feels_like = f"Feels like {fmt_temp(current['apparent_temperature'])}"
        temp_min = fmt_temp(daily["temperature_2m_min"][0])
        temp_max = fmt_temp(daily["temperature_2m_max"][0])
        wind_text = f"  {fmt_number(current['wind_speed_10m'], ' km/h')}"
        humidity_text = f"  {fmt_number(current['relative_humidity_2m'], '%')}"

        visibility_value = None
        if hourly.get("visibility"):
            visibility_value = hourly["visibility"][0] / 1000
        visibility_text = (
            f"  {fmt_number(visibility_value, ' km')}" if visibility_value is not None else "  N/A"
        )

        uv_index = daily.get("uv_index_max", [None])[0]
        uv_text = "N/A" if uv_index is None else str(round(uv_index))
        rain_chance = daily.get("precipitation_probability_max", [None])[0]
        prediction = (
            f"\n\n (today) {round(rain_chance)}%" if rain_chance is not None else ""
        )

        tooltip_text = str.format(
            "\t\t{}\t\t\n{}\n{}\n{}\n\n{}\n{}\n{}\n<small>{}</small>{}",
            f'<span size="xx-large">{temp}</span>',
            f"<big> {icon}</big>",
            f"<b>{status}</b>",
            f"<small>{feels_like}</small>",
            f"<b>  {temp_min}\t\t  {temp_max}</b>",
            f"{wind_text}\t{humidity_text}",
            f"{visibility_text}\tUV {uv_text}",
            location_label,
            f"<i> {prediction}</i>",
        )

        out_data = {
            "text": f"{icon}  {temp}",
            "alt": status,
            "tooltip": tooltip_text,
            "class": str(weather_code),
        }
        print(json.dumps(out_data))

        simple_weather = (
            f"{location_label}\n"
            f"{icon}  {status}\n"
            f"  {temp} ({feels_like})\n"
            f"  {temp_min} /   {temp_max}\n"
            f"{wind_text}\n"
            f"{humidity_text}\n"
            f"{visibility_text} UV {uv_text}\n"
        )

        with open(os.path.expanduser("~/.cache/.weather_cache"), "w") as file:
            file.write(simple_weather)
    except Exception as error:
        fallback = {
            "text": "  N/A",
            "alt": "Weather unavailable",
            "tooltip": f"Weather unavailable: {error}",
            "class": "default",
        }
        print(json.dumps(fallback))


if __name__ == "__main__":
    main()
