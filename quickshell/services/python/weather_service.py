#!/usr/bin/env python3
import urllib.request
import json
import datetime

def fetch_weather():
    city = "Local"
    temp = 22.0
    code = 0
    is_day = 1
    forecast_list = []
    
    try:
        # 1. Geolocation Lookup via ip-api
        req = urllib.request.Request("http://ip-api.com/json/", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=4) as response:
            loc = json.loads(response.read().decode())
            city = loc.get("city", "Local")
            lat = loc.get("lat", 0.0)
            lon = loc.get("lon", 0.0)

        # 2. Weather & 5-Day Forecast via Open-Meteo API
        url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&current_weather=true&daily=weathercode,temperature_2m_max&timezone=auto"
        req_weather = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req_weather, timeout=4) as resp_w:
            weather_data = json.loads(resp_w.read().decode())
            cw = weather_data.get("current_weather", {})
            temp = cw.get("temperature", temp)
            code = cw.get("weathercode", code)
            is_day = cw.get("is_day", is_day)

            daily = weather_data.get("daily", {})
            dates = daily.get("time", [])
            codes = daily.get("weathercode", [])
            temps = daily.get("temperature_2m_max", [])

            days_map = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

            for i in range(min(5, len(dates))):
                try:
                    d_obj = datetime.datetime.strptime(dates[i], "%Y-%m-%d")
                    d_name = "Today" if i == 0 else days_map[d_obj.weekday()]
                    forecast_list.append({
                        "day": d_name,
                        "temp": f"{round(temps[i])}°",
                        "code": codes[i]
                    })
                except Exception:
                    pass

    except Exception:
        pass

    forecast_json = json.dumps(forecast_list)
    print(f"{city}|||{temp}|||{code}|||{is_day}|||{forecast_json}", flush=True)

if __name__ == "__main__":
    fetch_weather()
