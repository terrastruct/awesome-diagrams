#!/bin/sh
set -eu
. "$(dirname "$0")/sub/lib.sh"
cd -- "$(dirname "$0")/.."

header "Starting diagram README update"

# Create temporary file for the updated README
TEMP_FILE=$(mktempd)/readme
log "Created temporary file: $TEMP_FILE"

# Ensure thumbnails directory exists
sh_c mkdir -p thumbnails

# Check if ImageMagick is available
if command -v convert >/dev/null; then
    log "ImageMagick found - thumbnail generation enabled"
else
    warn "ImageMagick not found - thumbnails will not be generated"
fi

# Copy the existing README up to the diagrams section
# Find the line number where "## Diagrams" appears, or use the whole file if not found
diagrams_line=$(grep -n "^## Diagrams" README.md | cut -d: -f1 || echo "999999")
if [ "$diagrams_line" != "999999" ]; then
    # Copy everything before the diagrams section
    head -n $((diagrams_line - 1)) README.md > "$TEMP_FILE"
    log "Found existing Diagrams section at line $diagrams_line, preserving content before it"
else
    # Copy the entire file if no diagrams section exists
    cp README.md "$TEMP_FILE"
    log "No existing Diagrams section found, preserving entire README"
fi

# Add diagram section header
_echo "" >> "$TEMP_FILE"
_echo "## Diagrams" >> "$TEMP_FILE"
_echo "" >> "$TEMP_FILE"

# Find all diagram.yml files and extract the diagram names
header "Searching for diagram files"
diagrams_file=$(mktempd)/diagrams
diagram_count=0

find ./diagrams -name "diagram.yml" -type f | while IFS= read -r file; do
    # Extract the relative path from the diagrams directory
    rel_path=$(_echo "$file" | sed 's|^\./diagrams/||' | sed 's|/diagram.yml$||')
    
    # Read the name from diagram.yml
    if [ -f "$file" ]; then
        name=$(grep '^name:' "$file" | sed 's/^name: *//' | sed 's/"//g' | sed "s/'//g")
        if [ -n "$name" ]; then
            # Store both name and path for sorting
            _echo "$name|$rel_path" >> "$diagrams_file"
            diagram_count=$((diagram_count + 1))
            FGCOLOR=2 logp "found" "$name at $rel_path"
        else
            warn "No name found in $file"
        fi
    fi
done

if [ -f "$diagrams_file" ]; then
    diagram_count=$(wc -l < "$diagrams_file")
    log "Found $diagram_count diagrams"
    
    # Sort diagrams alphabetically by name (case-insensitive)
    sort -t'|' -k1,1 -f "$diagrams_file" > "$diagrams_file.sorted"
    log "Sorted diagrams alphabetically"
else
    echoerr "No diagrams found"
    exit 1
fi

# Create results directory for parallel processing
results_dir=$(mktempd)/results
mkdir -p "$results_dir"

# Function to generate a single thumbnail
_generate_thumbnail() {
    # Find the first image in the diagram directory
    diagram_dir="./diagrams/$diagram_path"
    first_image=""
    
    # Check for images in order of preference: 1.svg, 1.png, 1.webp, 1.avif, 1.jpg
    for ext in svg png webp avif jpg; do
        if [ -f "$diagram_dir/1.$ext" ]; then
            first_image="$diagram_dir/1.$ext"
            break
        fi
    done
    
    # Generate result file
    result_file="$results_dir/$diagram_id"
    if [ -n "$first_image" ]; then
        thumbnail_path="thumbnails/${diagram_project}.png"
        
        # Create thumbnail using ImageMagick convert command
        if command -v convert >/dev/null 2>&1; then
            if hide convert "$first_image" -resize 150x -quality 85 "$thumbnail_path"; then
                _echo "success|$diagram_name|$diagram_project|$thumbnail_path" > "$result_file"
            else
                _echo "failed|$diagram_name|$diagram_project|" > "$result_file"
            fi
        else
            _echo "noconvert|$diagram_name|$diagram_project|" > "$result_file"
        fi
    else
        _echo "noimage|$diagram_name|$diagram_project|" > "$result_file"
    fi
}

# Process diagrams and generate thumbnails in parallel
header "Generating thumbnails in parallel"
line_num=0
while IFS='|' read -r diagram_name diagram_path; do
    line_num=$((line_num + 1))
    diagram_project=$(_echo "$diagram_path" | awk -F'/' '{print $NF}')
    diagram_id="$line_num-$diagram_project"
    export diagram_name diagram_path diagram_project diagram_id results_dir
    runjob "thumb-$diagram_id" _generate_thumbnail &
done < "$diagrams_file.sorted"

# Wait for all jobs to complete
waitjobs

# Function to truncate text with ellipsis if too long
truncate_text() {
    text="$1"
    max_len=20  # Maximum characters before truncating
    if [ $(printf %s "$text" | wc -c) -gt $max_len ]; then
        # Truncate and add ellipsis
        printf %s "$text" | cut -c1-$((max_len - 3))
        printf "..."
    else
        printf %s "$text"
    fi
}

# Function to convert name to URL slug
name_to_slug() {
    name="$1"
    # Convert to lowercase, replace spaces with hyphens, remove special characters
    printf %s "$name" | tr '[:upper:]' '[:lower:]' | sed 's/ /-/g' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g'
}

# Process results and write to README
header "Processing results and writing README"
thumbnails_generated=0
thumbnails_failed=0
no_image_found=0

# Start the grid container
cat >> "$TEMP_FILE" << 'EOF'
<div align="center">
<table>
<tr>
EOF

line_num=0
col_num=0
while IFS='|' read -r name path; do
    line_num=$((line_num + 1))
    project_name=$(_echo "$path" | awk -F'/' '{print $NF}')
    result_file="$results_dir/$line_num-$project_name"
    
    # Start new row every 8 items
    if [ $col_num -eq 8 ]; then
        _echo "</tr><tr>" >> "$TEMP_FILE"
        col_num=0
    fi
    
    _echo "<td align=\"center\" width=\"150\">" >> "$TEMP_FILE"
    
    if [ -f "$result_file" ]; then
        IFS='|' read -r status diagram_name project result_path < "$result_file"
        
        case "$status" in
            success)
                truncated_name=$(truncate_text "$diagram_name")
                url_slug=$(name_to_slug "$diagram_name")
                _echo "  <a href=\"https://softwarediagrams.com/diagrams/$url_slug\">" >> "$TEMP_FILE"
                _echo "    <img src=\"$result_path\" width=\"150\" alt=\"$diagram_name\"><br/>" >> "$TEMP_FILE"
                _echo "    <sub><b>$truncated_name</b></sub>" >> "$TEMP_FILE"
                _echo "  </a>" >> "$TEMP_FILE"
                thumbnails_generated=$((thumbnails_generated + 1))
                ;;
            failed|noimage|noconvert)
                truncated_name=$(truncate_text "$diagram_name")
                url_slug=$(name_to_slug "$diagram_name")
                _echo "  <a href=\"https://softwarediagrams.com/diagrams/$url_slug\">" >> "$TEMP_FILE"
                _echo "    <img src=\"https://via.placeholder.com/150x150/f0f0f0/808080?text=No+Image\" width=\"150\" alt=\"No thumbnail\"><br/>" >> "$TEMP_FILE"
                _echo "    <sub><b>$truncated_name</b></sub>" >> "$TEMP_FILE"
                _echo "  </a>" >> "$TEMP_FILE"
                if [ "$status" = "failed" ]; then
                    thumbnails_failed=$((thumbnails_failed + 1))
                elif [ "$status" = "noimage" ]; then
                    no_image_found=$((no_image_found + 1))
                fi
                ;;
        esac
    else
        # Fallback if result file is missing
        truncated_name=$(truncate_text "$name")
        url_slug=$(name_to_slug "$name")
        _echo "  <a href=\"https://softwarediagrams.com/diagrams/$url_slug\">" >> "$TEMP_FILE"
        _echo "    <img src=\"https://via.placeholder.com/150x150/f0f0f0/808080?text=No+Image\" width=\"150\" alt=\"No thumbnail\"><br/>" >> "$TEMP_FILE"
        _echo "    <sub><b>$truncated_name</b></sub>" >> "$TEMP_FILE"
        _echo "  </a>" >> "$TEMP_FILE"
        warn "No result file for $name"
    fi
    
    _echo "</td>" >> "$TEMP_FILE"
    col_num=$((col_num + 1))
done < "$diagrams_file.sorted"

# Fill empty cells in the last row if needed
while [ $col_num -lt 8 ] && [ $col_num -ne 0 ]; do
    _echo "<td></td>" >> "$TEMP_FILE"
    col_num=$((col_num + 1))
done

# Close the grid
cat >> "$TEMP_FILE" << 'EOF'
</tr>
</table>
</div>
EOF


# Replace the original README with the updated one
sh_c mv "$TEMP_FILE" README.md

bigheader "Summary"
log "Total diagrams: $diagram_count"
log "Thumbnails generated: $thumbnails_generated"
log "Thumbnails failed: $thumbnails_failed"
log "Diagrams without images: $no_image_found"
FGCOLOR=2 header "README.md has been updated successfully"