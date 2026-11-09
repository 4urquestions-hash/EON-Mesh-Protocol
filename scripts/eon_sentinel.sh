#!/bin/bash

# EON SENTINEL MONITOR v1.0
# Autonomous Host Optimization & Model Switching

LOG_FILE="/home/tc/eon_sentinel.log"
RAM_WARN=85
RAM_CRIT=95
CURRENT_MODEL="qwen2.5-coder:7b-instruct"
FALLBACK_MODEL="qwen2.5-coder:1.5b"

log_event() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SENTINEL] $1" >> "$LOG_FILE"
}

get_ram_usage() {
    free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}'
}

optimize_system() {
    log_event "WARNING: RAM at ${RAM_USAGE}%. Initiating self-heal protocols."
    
    # 1. Stop idle Ollama models to free VRAM/RAM
    ollama ps | awk 'NR>1 {print $1}' | while read model; do
        log_event "Stopping idle model: $model"
        ollama stop "$model" 2>/dev/null
    done

    # 2. Clear system caches (safe, non-destructive)
    sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1 || log_event "Could not clear kernel caches (requires sudo)."
    
    # 3. Model Switching: If critical, force fallback to 1.5B
    if [ "$RAM_USAGE" -ge "$RAM_CRIT" ]; then
        log_event "CRITICAL: RAM at ${RAM_USAGE}%. Switching active context to $FALLBACK_MODEL."
        ollama stop "$CURRENT_MODEL" 2>/dev/null
        # Pre-load the lightweight model so it's ready
        echo "test" | ollama run "$FALLBACK_MODEL" "ack" >/dev/null 2>&1 &
    fi
}

# Main Loop
while true; do
    RAM_USAGE=$(get_ram_usage)
    
    if [ "$RAM_USAGE" -ge "$RAM_WARN" ]; then
        optimize_system
    fi
    
    # Check every 30 seconds
    sleep 30
done
