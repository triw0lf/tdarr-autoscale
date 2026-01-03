#!/bin/bash
#
# Tdarr Autoscale - Dynamic worker scaling based on Plex activity
# 
# Automatically scales Tdarr GPU workers down when people are streaming
# and back up when Plex is idle. Supports both Tautulli and direct Plex API.
#
# Features:
#   - Scales workers based on active Plex streams
#   - Day/Night mode with different worker limits
#   - Auto-detects Tdarr node ID
#   - Works with Tautulli OR direct Plex API
#
# Requirements: curl, jq
#
# Installation:
#   1. Save this script (e.g., /home/user/scripts/tdarr-autoscale.sh)
#   2. Make executable: chmod +x tdarr-autoscale.sh
#   3. Configure the variables below
#   4. Test: ./tdarr-autoscale.sh
#   5. Add to cron for automatic scaling:
#      crontab -e
#      */5 * * * * /path/to/tdarr-autoscale.sh >> /path/to/tdarr-autoscale.log 2>&1
#
# Optional - log rotation (add to crontab, clears log weekly):
#   0 0 * * 0 > /path/to/tdarr-autoscale.log
#
# GitHub: [your gist URL here]

#######################
# CONFIGURATION
#######################

# Tdarr settings
TDARR_URL="http://localhost:8265"

# Plex monitoring - choose ONE method:

# Option 1: Tautulli (recommended - more reliable)
USE_TAUTULLI=true
TAUTULLI_URL="http://localhost:8181"
TAUTULLI_API_KEY="YOUR_TAUTULLI_API_KEY"    # Settings > Web Interface > API Key

# Option 2: Direct Plex API (if no Tautulli)
# Set USE_TAUTULLI=false and configure these:
PLEX_URL="http://localhost:32400"
PLEX_TOKEN="YOUR_PLEX_TOKEN"                # See: https://support.plex.tv/articles/204059436

# Worker limits - adjust to your hardware capability
# Intel Quick Sync typically handles 3-5 concurrent transcodes well
WORKERS_IDLE=3          # No one watching (daytime)
WORKERS_ACTIVE=1        # Someone is streaming
WORKERS_NIGHT=4         # No one watching (night)
WORKERS_NIGHT_ACTIVE=2  # Streaming during night

# Night mode hours (24h format)
NIGHT_START=0   # Midnight
NIGHT_END=5     # 5 AM

#######################
# SCRIPT - no edits needed below
#######################

# Get node ID dynamically (first node found)
NODE_ID=$(curl -s "${TDARR_URL}/api/v2/get-nodes" | jq -r 'keys[0]')

if [ -z "$NODE_ID" ] || [ "$NODE_ID" = "null" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Could not get Tdarr node ID"
    exit 1
fi

# Get current worker limit from Tdarr
CURRENT=$(curl -s "${TDARR_URL}/api/v2/get-nodes" | jq -r ".\"${NODE_ID}\".workerLimits.transcodegpu")

# Get current hour (0-23)
HOUR=$(date +%H)
# Remove leading zero for comparison
HOUR=$((10#$HOUR))

# Check if night mode
if [ "$HOUR" -ge "$NIGHT_START" ] && [ "$HOUR" -lt "$NIGHT_END" ]; then
    IS_NIGHT=true
else
    IS_NIGHT=false
fi

# Get active Plex streams
if [ "$USE_TAUTULLI" = true ]; then
    STREAMS=$(curl -s "${TAUTULLI_URL}/api/v2?apikey=${TAUTULLI_API_KEY}&cmd=get_activity" | jq -r '.response.data.stream_count // 0')
else
    STREAMS=$(curl -s "${PLEX_URL}/status/sessions?X-Plex-Token=${PLEX_TOKEN}" | grep -oP 'MediaContainer size="\K[0-9]+' || echo "0")
fi

# Handle empty/null response
if [ -z "$STREAMS" ] || [ "$STREAMS" = "null" ]; then
    STREAMS=0
fi

# Determine target workers
if [ "$IS_NIGHT" = true ]; then
    if [ "$STREAMS" -eq 0 ]; then
        TARGET_WORKERS=$WORKERS_NIGHT
    else
        TARGET_WORKERS=$WORKERS_NIGHT_ACTIVE
    fi
else
    if [ "$STREAMS" -eq 0 ]; then
        TARGET_WORKERS=$WORKERS_IDLE
    else
        TARGET_WORKERS=$WORKERS_ACTIVE
    fi
fi

# Set time mode for logging
if [ "$IS_NIGHT" = true ]; then
    TIME_MODE="Night"
else
    TIME_MODE="Day"
fi

# Only make API calls if change needed
if [ "$CURRENT" -ne "$TARGET_WORKERS" ]; then
    ORIGINAL=$CURRENT
    if [ "$CURRENT" -lt "$TARGET_WORKERS" ]; then
        while [ "$CURRENT" -lt "$TARGET_WORKERS" ]; do
            curl -s -X POST "${TDARR_URL}/api/v2/alter-worker-limit" \
                -H "Content-Type: application/json" \
                -d '{"data":{"nodeID":"'"${NODE_ID}"'","workerType":"transcodegpu","process":"increase"}}' > /dev/null
            CURRENT=$((CURRENT + 1))
        done
        DIFF="+$((TARGET_WORKERS - ORIGINAL))"
    else
        while [ "$CURRENT" -gt "$TARGET_WORKERS" ]; do
            curl -s -X POST "${TDARR_URL}/api/v2/alter-worker-limit" \
                -H "Content-Type: application/json" \
                -d '{"data":{"nodeID":"'"${NODE_ID}"'","workerType":"transcodegpu","process":"decrease"}}' > /dev/null
            CURRENT=$((CURRENT - 1))
        done
        DIFF="-$((ORIGINAL - TARGET_WORKERS))"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Streams: $STREAMS | Mode: $TIME_MODE | Workers: $TARGET_WORKERS ($DIFF)"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Streams: $STREAMS | Mode: $TIME_MODE | Workers: $TARGET_WORKERS (no change)"
fi
