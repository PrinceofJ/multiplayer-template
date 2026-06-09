#!/bin/bash
# Launches multiple Godot instances for local multiplayer testing.
# Usage: ./debug_launch.sh [num_players]
#   num_players: 2-4 (default: 2)
#
# Set GODOT_PATH environment variable if 'godot' is not in your PATH.
# Example: GODOT_PATH="/Applications/Godot.app/Contents/MacOS/Godot" ./debug_launch.sh 3

NUM_PLAYERS=${1:-2}
GODOT_PATH="${GODOT_PATH:-godot}"
PROJECT_PATH="$(cd "$(dirname "$0")" && pwd)"

if [ "$NUM_PLAYERS" -lt 2 ] || [ "$NUM_PLAYERS" -gt 4 ]; then
    echo "Usage: $0 [2-4]"
    exit 1
fi

echo "Launching $NUM_PLAYERS instances..."
echo "Godot: $GODOT_PATH"
echo "Project: $PROJECT_PATH"
echo ""

# Launch server (player 1)
echo "Starting server (Player 1)..."
"$GODOT_PATH" --path "$PROJECT_PATH" -- --server &

sleep 1

# Launch clients (players 2-N)
for i in $(seq 2 "$NUM_PLAYERS"); do
    echo "Starting client (Player $i)..."
    "$GODOT_PATH" --path "$PROJECT_PATH" -- --client &
    sleep 0.5
done

echo ""
echo "All $NUM_PLAYERS instances launched. Close all windows or press Ctrl+C to stop."
wait
