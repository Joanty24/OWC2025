#!/bin/bash

# Source the config file to get $API_KEY
source config.sh

# API (for reference)
# Geocoding: http://api.openweathermap.org/geo/1.0/direct?q={city name}&limit={limit}&appid={API key}
# One Call:  https://api.openweathermap.org/data/3.0/onecall?lat={lat}&lon={lon}&exclude={part}&appid={API key}

# Variables
city="Reus"
language="en"
exclude="minutely,hourly,daily,alerts"

# Geocoding API call
geo_response=$(curl -s "http://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=$API_KEY" | tee city.json)

# latitude and longitude parsing
# 'jq -r' gets the "raw" string value (without quotes)
# '.[0]' gets the first item from the JSON array
lat=$(echo "$geo_response" | jq -r '.[0].lat')
lon=$(echo "$geo_response" | jq -r '.[0].lon')

# Check if we got valid coordinates
if [ -z "$lat" ] || [ "$lat" == "null" ]; then
  echo "Error: Could not find coordinates for $city."
  echo "Response: $geo_response"
  exit 1
fi

# Call One Call API
onecall_response=$(curl -s "https://api.openweathermap.org/data/3.0/onecall?lat=$lat&lon=$lon&exclude=$exclude&units=metric&lang=$language&appid=$API_KEY" | tee lastcall.json)
