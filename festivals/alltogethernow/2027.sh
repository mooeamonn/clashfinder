#!/usr/bin/env bash

# load session key
# session key can be obtained by using PCAPdroid to capture network traffic from the AllTogetherNow app in a Android Studio emulated device and copying the value of the x-protect header from a request to the artists endpoint.
# TODO: before this runs for real, recapture SESSION_KEY plus the user-agent build number, x-app-version, and x-os-version below against the 2027 app release — they're tied to the app build captured for 2026 and will be stale.
[[ ! -f .env ]] && echo "ERROR: env file with session key missing" && exit 1
set -o allexport; source .env; set +o allexport

DESTINATION_DIR=$(pwd)/2027

mkdir -p "${DESTINATION_DIR}"

NORMALIZE_APPMIRAL_JSON='
  del(..|.modified_at?)
  | .data |= (
    map(
      if (.performances? | type) == "array" then
        .performances |= sort_by(.id // .external_id // .start_time // "")
      else
        .
      end
      | if (.tracks? | type) == "array" then
        .tracks |= sort_by(.track_id // .title // "")
      else
        .
      end
      | if (.tags? | type) == "array" then
        .tags |= sort_by(.slug // .name // "")
      else
        .
      end
    )
    | sort_by(.id // .external_id // .name // "")
  )
'

# Fetching lineup
curl -s --http2 --compressed -k -G -H "accept-language: en" -H "accept-encoding: gzip" -H 'content-type: application/json' -H 'accept: application/json' --compressed -H "x-protect: $SESSION_KEY" -H 'accept-language: en' -H 'user-agent: AllTogetherNow-2026/497 CFNetwork/3826.500.131 Darwin/25.5.0' -H 'x-app-version: 8.0.0' -H 'x-os-version: 26.5' -H 'x-platform: ios' 'https://app.appmiral.com/api/v7/events/alltogethernow/editions/alltogethernow2026/artists?max_per_page=1000' | \
  # Remove volatile fields and normalize API order.
  jq -S "${NORMALIZE_APPMIRAL_JSON}" > "${DESTINATION_DIR}/alltogethernow.artists.json"
# Fetching stages
curl -s --http2 --compressed -k -G -H "accept-language: en" -H "accept-encoding: gzip" -H 'content-type: application/json' -H 'accept: application/json' --compressed -H "x-protect: $SESSION_KEY" -H 'accept-language: en' -H 'user-agent: AllTogetherNow-2026/497 CFNetwork/3826.500.131 Darwin/25.5.0' -H 'x-app-version: 8.0.0' -H 'x-os-version: 26.5' -H 'x-platform: ios' -H "if-modified-since: Thu, 01 Jul 2026 12:00:00 GMT" 'https://app.appmiral.com/api/v7/events/alltogethernow/editions/alltogethernow2026/stages?max_per_page=500' | \
  # Remove volatile fields and normalize API order.
  jq -S "${NORMALIZE_APPMIRAL_JSON}" > "${DESTINATION_DIR}/alltogethernow.stages.json"

uv run ../../bin/appmiral_transform.py --tz "Europe/Dublin" --artists "${DESTINATION_DIR}/alltogethernow.artists.json" --stages "${DESTINATION_DIR}/alltogethernow.stages.json" > "${DESTINATION_DIR}/clashfinder.txt"
rm "${DESTINATION_DIR}/alltogethernow.stages.json"
rm "${DESTINATION_DIR}/alltogethernow.artists.json"

# uv run ../../bin/clashfinder.py --name atn2027 --path "${DESTINATION_DIR}/clashfinder.txt"
