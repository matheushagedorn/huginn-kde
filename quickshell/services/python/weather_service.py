#!/usr/bin/env python3
"""Current conditions and a five-day forecast, from Open-Meteo.

Three things were wrong with the previous version. It resolved the location
through ip-api.com over plain HTTP, which is unreachable from here, so the
lookup always failed. Every failure was swallowed by a bare `except: pass`, and
what got printed was the placeholder it had started with — a permanent "Local,
clear, 22°C" that looked like real weather. And there was no way to say where
you actually are.

Now: the city can be set by hand, auto-detection tries more than one provider,
the resolved coordinates are cached, and a failure is reported as a failure.

Configuration, all fields optional, in ~/.config/huginn_weather.json:

    {"city": "Joinville"}                        resolved by name
    {"city": "Home", "latitude": -26.3, "longitude": -48.8}   exact

Written with no configuration at all, it detects the location by IP.
"""
import json
import os
import sys
import time
import datetime
import urllib.parse
import urllib.request

CONFIG_PATH = os.path.expanduser('~/.config/huginn_weather.json')
CACHE_PATH = os.path.expanduser('~/.cache/huginn/weather-location.json')
CACHE_TTL = 24 * 60 * 60

# Plain HTTP is refused on this network, and any single provider can be down or
# rate limited, so auto-detection tries a few and takes the first that answers.
IP_PROVIDERS = [
    ('https://ipwho.is/', ('city',), ('latitude',), ('longitude',)),
    ('https://get.geojs.io/v1/ip/geo.json', ('city',), ('latitude',), ('longitude',)),
    ('https://ipapi.co/json/', ('city',), ('latitude',), ('longitude',)),
]

DAY_NAMES = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']


def get_json(url, timeout=6):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.loads(response.read().decode())


def read_config():
    try:
        with open(CONFIG_PATH) as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def read_cache():
    try:
        with open(CACHE_PATH) as handle:
            data = json.load(handle)
        if time.time() - data.get('resolved_at', 0) < CACHE_TTL:
            return data
    except Exception:
        pass
    return None


def write_cache(location):
    try:
        os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
        payload = dict(location)
        payload['resolved_at'] = time.time()
        with open(CACHE_PATH, 'w') as handle:
            json.dump(payload, handle)
    except Exception:
        pass


def geocode(name):
    """City name to coordinates, through Open-Meteo's own geocoder."""
    url = ('https://geocoding-api.open-meteo.com/v1/search?name='
           + urllib.parse.quote(name) + '&count=1&format=json')
    results = get_json(url).get('results') or []
    if not results:
        raise LookupError(f'no match for "{name}"')
    hit = results[0]
    return {
        'city': hit['name'],
        'latitude': hit['latitude'],
        'longitude': hit['longitude'],
    }


def locate_by_ip():
    errors = []
    for url, city_keys, lat_keys, lon_keys in IP_PROVIDERS:
        try:
            data = get_json(url, timeout=5)
            city = next((data[k] for k in city_keys if data.get(k)), None)
            lat = next((data[k] for k in lat_keys if data.get(k) is not None), None)
            lon = next((data[k] for k in lon_keys if data.get(k) is not None), None)
            if city and lat is not None and lon is not None:
                return {'city': city, 'latitude': float(lat), 'longitude': float(lon)}
        except Exception as exc:
            errors.append(f'{url}: {type(exc).__name__}')
    raise LookupError('; '.join(errors) or 'no provider answered')


def resolve_location():
    config = read_config()

    # Coordinates given outright win, and need no network at all.
    if config.get('latitude') is not None and config.get('longitude') is not None:
        return {
            'city': config.get('city') or 'Home',
            'latitude': float(config['latitude']),
            'longitude': float(config['longitude']),
        }

    cached = read_cache()
    wanted = config.get('city')
    if cached and cached.get('requested') == wanted:
        return cached

    if wanted:
        location = geocode(wanted)
    else:
        location = locate_by_ip()

    location['requested'] = wanted
    write_cache(location)
    return location


def fetch_forecast(location):
    url = ('https://api.open-meteo.com/v1/forecast'
           f"?latitude={location['latitude']}&longitude={location['longitude']}"
           '&current_weather=true&daily=weathercode,temperature_2m_max&timezone=auto')
    data = get_json(url)

    current = data.get('current_weather') or {}
    daily = data.get('daily') or {}
    dates = daily.get('time') or []
    codes = daily.get('weathercode') or []
    temps = daily.get('temperature_2m_max') or []

    forecast = []
    for i in range(min(5, len(dates), len(codes), len(temps))):
        try:
            parsed = datetime.datetime.strptime(dates[i], '%Y-%m-%d')
            forecast.append({
                'day': 'Today' if i == 0 else DAY_NAMES[parsed.weekday()],
                'temp': f'{round(temps[i])}°',
                'code': codes[i],
            })
        except Exception:
            continue

    return {
        'ok': True,
        'city': location['city'],
        'temp': current.get('temperature'),
        'code': current.get('weathercode', 0),
        'isDay': current.get('is_day', 1),
        'forecast': forecast,
    }


def main():
    try:
        report = fetch_forecast(resolve_location())
        if report['temp'] is None:
            raise ValueError('no temperature in the response')
    except Exception as exc:
        # Reported, not hidden behind a plausible-looking placeholder.
        report = {'ok': False, 'error': f'{type(exc).__name__}: {exc}'}
        print(json.dumps(report), flush=True)
        return 1

    print(json.dumps(report), flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
