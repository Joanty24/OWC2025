#!/bin/bash

# Source the config file to get $API_KEY
source "$(dirname "$0")/config.sh"

# API (for reference)
# Geocoding: http://api.openweathermap.org/geo/1.0/direct?q={city name}&limit={limit}&appid={API key}
# One Call:  https://api.openweathermap.org/data/3.0/onecall?lat={lat}&lon={lon}&exclude={part}&appid={API key}

# Force C locale for consistent numeric and date formatting
export LC_NUMERIC=C
export LC_TIME=C

# --- Colors ---
BOLD='\033[1m'
RESET='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'

# --- Variables ---
city="${1:-Reus}"
language="en"
exclude="minutely,alerts"

# --- Helper: weather icon from condition ID ---
weather_icon() {
  local id=$1
  if   (( id >= 200 && id < 300 )); then echo "⛈"
  elif (( id >= 300 && id < 400 )); then echo "🌦"
  elif (( id >= 500 && id < 600 )); then echo "🌧"
  elif (( id >= 600 && id < 700 )); then echo "❄️"
  elif (( id >= 700 && id < 800 )); then echo "🌫"
  elif (( id == 800 ));             then echo "☀️"
  elif (( id > 800 ));              then echo "☁️"
  else echo "🌡"
  fi
}

# --- Helper: wind direction arrow (wind blows FROM this bearing) ---
wind_dir_arrow() {
  local deg=$1
  # 0/360=N(from north→blows south ↓), 90=E(→blows west ←), 180=S(→blows north ↑), 270=W(→blows east →)
  local dirs=("N↓" "NE↙" "E←" "SE↖" "S↑" "SW↗" "W→" "NW↘")
  local idx=$(( (deg + 22) / 45 % 8 ))
  echo "${dirs[$idx]}"
}

# --- Geocoding ---
city_encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$city")
echo -e "${CYAN}🔍 Looking up ${BOLD}$city${RESET}${CYAN}...${RESET}"
geo_response=$(curl -s "http://api.openweathermap.org/geo/1.0/direct?q=${city_encoded}&limit=1&appid=$API_KEY" | tee city.json)

lat=$(echo "$geo_response" | jq -r '.[0].lat')
lon=$(echo "$geo_response" | jq -r '.[0].lon')
city_name=$(echo "$geo_response" | jq -r '.[0].name')
country=$(echo "$geo_response" | jq -r '.[0].country')

if [ -z "$lat" ] || [ "$lat" == "null" ]; then
  echo -e "${RED}Error: Could not find coordinates for \"$city\".${RESET}"
  exit 1
fi

# --- One Call API ---
onecall_response=$(curl -s "https://api.openweathermap.org/data/3.0/onecall?lat=$lat&lon=$lon&exclude=$exclude&units=metric&lang=$language&appid=$API_KEY" | tee lastcall.json)

# Timezone for city-local time display
city_tz=$(echo "$onecall_response" | jq -r '.timezone')

# --- Parse current weather ---
temp=$(echo "$onecall_response"        | jq -r '.current.temp')
feels=$(echo "$onecall_response"       | jq -r '.current.feels_like')
humidity=$(echo "$onecall_response"    | jq -r '.current.humidity')
pressure=$(echo "$onecall_response"    | jq -r '.current.pressure')
uvi=$(echo "$onecall_response"         | jq -r '.current.uvi')
visibility=$(echo "$onecall_response"  | jq -r '.current.visibility')
wind_speed=$(echo "$onecall_response"  | jq -r '.current.wind_speed')
wind_deg=$(echo "$onecall_response"    | jq -r '.current.wind_deg')
clouds=$(echo "$onecall_response"      | jq -r '.current.clouds')
description=$(echo "$onecall_response" | jq -r '.current.weather[0].description')
cond_id=$(echo "$onecall_response"     | jq -r '.current.weather[0].id')
sunrise=$(echo "$onecall_response"     | jq -r '.current.sunrise')
sunset=$(echo "$onecall_response"      | jq -r '.current.sunset')

icon=$(weather_icon "$cond_id")
wind_arrow=$(wind_dir_arrow "$wind_deg")
sunrise_fmt=$(TZ="$city_tz" date -d "@$sunrise" '+%H:%M')
sunset_fmt=$(TZ="$city_tz" date -d "@$sunset" '+%H:%M')
vis_km=$(echo "scale=1; $visibility/1000" | bc)

# --- Parse hourly forecast (next 6 hours) ---
hourly=$(echo "$onecall_response" | jq -r '.hourly[:6][] | "\(.dt)|\(.temp)|\(.weather[0].id)|\(.weather[0].description)|\(.pop)"')

# --- Parse daily forecast (next 5 days) ---
daily=$(echo "$onecall_response" | jq -r '.daily[:5][] | "\(.dt)|\(.temp.min)|\(.temp.max)|\(.weather[0].id)|\(.weather[0].description)|\(.pop)"')

# --- Display ---
echo ""
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${icon}  ${BOLD}${city_name}, ${country}${RESET}  —  $(echo "$description" | sed 's/\b./\u&/g')"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${YELLOW}🌡  Temp:${RESET}       ${BOLD}${temp}°C${RESET}  (feels like ${feels}°C)"
echo -e "  ${YELLOW}💧 Humidity:${RESET}    ${humidity}%"
echo -e "  ${YELLOW}🌬  Wind:${RESET}       ${wind_speed} m/s  ${wind_arrow} (${wind_deg}°)"
echo -e "  ${YELLOW}☁️  Clouds:${RESET}     ${clouds}%"
echo -e "  ${YELLOW}🔭 Visibility:${RESET}  ${vis_km} km"
echo -e "  ${YELLOW}📊 Pressure:${RESET}   ${pressure} hPa"
echo -e "  ${YELLOW}☀️  UV Index:${RESET}   ${uvi}"
echo -e "  ${YELLOW}🌅 Sunrise:${RESET}    ${sunrise_fmt}   🌇 Sunset: ${sunset_fmt}  ${CYAN}(${city_tz})${RESET}"

# --- Hourly forecast ---
echo ""
echo -e "${BOLD}${GREEN}  ⏱  Next 6 Hours${RESET}"
echo -e "${GREEN}  ──────────────────────────────────────────${RESET}"
while IFS='|' read -r h_dt h_temp h_id h_desc h_pop; do
  h_icon=$(weather_icon "$h_id")
  h_time=$(TZ="$city_tz" date -d "@$h_dt" '+%H:%M')
  h_pop_pct=$(echo "scale=0; $h_pop * 100 / 1" | bc)
  printf "  ${CYAN}%s${RESET}  %s  %-22s  ${BOLD}%5.1f°C${RESET}  🌂%3s%%\n" \
    "$h_time" "$h_icon" "$h_desc" "$h_temp" "$h_pop_pct"
done <<< "$hourly"

# --- Daily forecast ---
echo ""
echo -e "${BOLD}${GREEN}  📅  5-Day Forecast${RESET}"
echo -e "${GREEN}  ──────────────────────────────────────────${RESET}"
while IFS='|' read -r d_dt d_min d_max d_id d_desc d_pop; do
  d_icon=$(weather_icon "$d_id")
  d_day=$(TZ="$city_tz" date -d "@$d_dt" '+%a %d %b')
  d_pop_pct=$(echo "scale=0; $d_pop * 100 / 1" | bc)
  printf "  ${CYAN}%-11s${RESET}  %s  %-22s  ${BLUE}%4.1f°C${RESET} / ${RED}%4.1f°C${RESET}  🌂%3s%%\n" \
    "$d_day" "$d_icon" "$d_desc" "$d_min" "$d_max" "$d_pop_pct"
done <<< "$daily"

echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
