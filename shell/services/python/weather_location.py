#!/usr/bin/env python3
"""Search for a place, and pin the one you picked.

Backs the city picker in the weather panel, so choosing where you are is a
thing you do in the interface rather than by editing JSON by hand.

    weather_location.py search "joinville"
    weather_location.py set "Joinville" -26.30444 -48.84556 "Santa Catarina, Brasil"
    weather_location.py clear
"""
import json
import os
import sys
import urllib.parse
import urllib.request

CONFIG_PATH = os.path.expanduser('~/.config/huginn_weather.json')
CACHE_PATH = os.path.expanduser('~/.cache/huginn/weather-location.json')


def search(query):
    query = query.strip()
    if len(query) < 2:
        return {'ok': True, 'results': []}

    url = ('https://geocoding-api.open-meteo.com/v1/search?name='
           + urllib.parse.quote(query) + '&count=5&format=json')
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=6) as response:
        payload = json.loads(response.read().decode())

    results = []
    for hit in payload.get('results') or []:
        # Region and country disambiguate the many places that share a name.
        region = ', '.join(p for p in (hit.get('admin1'), hit.get('country')) if p)
        results.append({
            'name': hit['name'],
            'region': region,
            'latitude': hit['latitude'],
            'longitude': hit['longitude'],
        })
    return {'ok': True, 'results': results}


def set_location(name, latitude, longitude, region=''):
    config = {
        'city': name,
        'region': region,
        'latitude': float(latitude),
        'longitude': float(longitude),
    }
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    with open(CONFIG_PATH, 'w') as handle:
        json.dump(config, handle, indent=2, ensure_ascii=False)
        handle.write('\n')

    # The cache holds whatever was resolved before; leaving it would keep the
    # old place until it expired.
    try:
        os.remove(CACHE_PATH)
    except FileNotFoundError:
        pass
    return {'ok': True, 'city': name}


def clear():
    """Back to detecting the location by IP."""
    for path in (CONFIG_PATH, CACHE_PATH):
        try:
            os.remove(path)
        except FileNotFoundError:
            pass
    return {'ok': True}


def main():
    args = sys.argv[1:]
    try:
        if not args:
            raise ValueError('no command')
        if args[0] == 'search':
            result = search(args[1] if len(args) > 1 else '')
        elif args[0] == 'set':
            result = set_location(args[1], args[2], args[3],
                                  args[4] if len(args) > 4 else '')
        elif args[0] == 'clear':
            result = clear()
        else:
            raise ValueError(f'unknown command "{args[0]}"')
    except Exception as exc:
        print(json.dumps({'ok': False, 'error': f'{type(exc).__name__}: {exc}'}), flush=True)
        return 1

    print(json.dumps(result, ensure_ascii=False), flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
