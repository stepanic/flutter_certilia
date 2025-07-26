#!/bin/bash

# Flutter run with real-time logging
# This script runs Flutter app and saves logs to a file that can be tailed

LOG_DIR="/tmp/flutter_certilia_logs"
LOG_FILE="$LOG_DIR/flutter_run.log"
PID_FILE="$LOG_DIR/flutter_run.pid"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to stop previous instance
stop_previous() {
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            echo "Stopping previous Flutter instance (PID: $OLD_PID)..."
            kill -TERM "$OLD_PID" 2>/dev/null
            sleep 2
            # Force kill if still running
            if ps -p "$OLD_PID" > /dev/null 2>&1; then
                kill -KILL "$OLD_PID" 2>/dev/null
            fi
        fi
        rm -f "$PID_FILE"
    fi
}

# Parse arguments
DEVICE="ZY22G9DDR3"
TARGET="lib/main_extended.dart"
COMMAND="run"

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--device)
            DEVICE="$2"
            shift 2
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        stop)
            COMMAND="stop"
            shift
            ;;
        logs)
            COMMAND="logs"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

case $COMMAND in
    stop)
        stop_previous
        echo "Flutter app stopped."
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            echo "Following Flutter logs (Ctrl+C to stop)..."
            tail -f "$LOG_FILE"
        else
            echo "No log file found. Run the app first."
        fi
        ;;
    run)
        # Stop any previous instance
        stop_previous
        
        # Clear previous log
        > "$LOG_FILE"
        
        echo "Starting Flutter app..."
        echo "Device: $DEVICE"
        echo "Target: $TARGET"
        echo "Logs: $LOG_FILE"
        echo "---"
        
        # Run Flutter in background and save PID
        nohup flutter run -d "$DEVICE" -t "$TARGET" > "$LOG_FILE" 2>&1 &
        FLUTTER_PID=$!
        echo "$FLUTTER_PID" > "$PID_FILE"
        
        echo "Flutter app started (PID: $FLUTTER_PID)"
        echo ""
        echo "To view logs in real-time:"
        echo "  tail -f $LOG_FILE"
        echo ""
        echo "Or use:"
        echo "  ./run_with_logs.sh logs"
        echo ""
        echo "To stop the app:"
        echo "  ./run_with_logs.sh stop"
        ;;
esac