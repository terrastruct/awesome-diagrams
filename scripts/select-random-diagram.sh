#!/bin/bash

# Script to select a random diagram with multiple images that hasn't been featured

# Get featured diagrams
featured_diagrams=()
for featured_file in featured/*/*.yml; do
    if [ -f "$featured_file" ]; then
        diagram=$(grep "^diagram:" "$featured_file" | cut -d' ' -f2)
        if [ -n "$diagram" ]; then
            featured_diagrams+=("$diagram")
        fi
    fi
done

# Find diagrams with multiple images that haven't been featured
available_diagrams=()
for diagram_yml in diagrams/*/*/*/diagram.yml diagrams/*/*/*/*/diagram.yml; do
    if [ -f "$diagram_yml" ]; then
        # Count image entries
        image_count=$(grep -c "^  - " "$diagram_yml" 2>/dev/null || echo "0")
        
        if [ "$image_count" -gt 1 ]; then
            # Get the path relative to diagrams/
            diagram_path=$(dirname "$diagram_yml" | sed 's|diagrams/||')
            
            # Check if already featured
            is_featured=false
            for featured in "${featured_diagrams[@]}"; do
                if [ "$featured" = "$diagram_path" ]; then
                    is_featured=true
                    break
                fi
            done
            
            if [ "$is_featured" = false ]; then
                available_diagrams+=("$diagram_path")
            fi
        fi
    fi
done

# Select a random diagram from available ones
if [ ${#available_diagrams[@]} -eq 0 ]; then
    echo "No available diagrams found" >&2
    exit 1
fi

# Use RANDOM to select a random index
random_index=$((RANDOM % ${#available_diagrams[@]}))
selected_diagram="${available_diagrams[$random_index]}"

echo "$selected_diagram"