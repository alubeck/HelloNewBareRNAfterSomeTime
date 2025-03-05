#!/bin/bash

# Check if a new name was provided
if [ $# -eq 0 ]; then
    echo "Error: No new name provided."
    echo "Usage: $0 <NewProjectName>"
    exit 1
fi

OLD_NAME="HelloNewBareRNAfterSomeTime"
NEW_NAME="$1"
LC_OLD_NAME=$(echo "$OLD_NAME" | tr '[:upper:]' '[:lower:]')
LC_NEW_NAME=$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]')

echo "Renaming project from '$OLD_NAME' to '$NEW_NAME'..."
echo "This will update file contents, filenames, and directory names."
echo "Press Ctrl+C to cancel or any key to continue..."
read -n 1

# Get script's location for later use
SCRIPT_PATH=$(realpath "$0")
SCRIPT_NAME=$(basename "$0")

# Step 1: Replace text inside files (case-insensitive)
echo "Replacing text inside files..."

# Explicitly handle important JSON files first
JSON_FILES=(
    "./package.json"
    "./app.json"
    "./package-lock.json"
)

for json_file in "${JSON_FILES[@]}"; do
    if [[ -f "$json_file" ]]; then
        echo "Modifying contents of: $json_file"
        sed -i '' "s/$OLD_NAME/$NEW_NAME/g" "$json_file"
        sed -i '' "s/$LC_OLD_NAME/$LC_NEW_NAME/g" "$json_file"
    fi
done

# Then handle all other files
grep -r -l -i "$OLD_NAME" --include="*" . | while read -r file; do
    # Skip this script itself
    if [[ "$file" == "./$SCRIPT_NAME" ]]; then
        continue
    fi
    
    # Skip binary files and non-regular files
    if [[ ! -f "$file" ]] || [[ -z "$(file -b --mime "$file" | grep -i "text")" ]]; then
        continue
    fi
    
    echo "Modifying contents of: $file"
    # Handle case-preserving replacement
    sed -i '' "s/$OLD_NAME/$NEW_NAME/g" "$file"
    sed -i '' "s/$LC_OLD_NAME/$LC_NEW_NAME/g" "$file"
done

# Step 2: Create a list of files and directories to rename (from deepest to shallowest)
echo "Creating list of files and directories to rename..."
find . -depth -type f -o -type d | grep -i "$OLD_NAME" > files_to_rename.txt

# Step 3: Rename files and directories (from deepest to shallowest)
echo "Renaming files and directories..."
while read -r path; do
    # Skip this script and the temp file
    if [[ "$path" == "./$SCRIPT_NAME" ]] || [[ "$path" == "./files_to_rename.txt" ]]; then
        continue
    fi
    
    dir=$(dirname "$path")
    base=$(basename "$path")
    
    # Replace all occurrences of old name in the filename (case-sensitive)
    new_base=$(echo "$base" | sed "s/$OLD_NAME/$NEW_NAME/g")
    
    # Also try case-insensitive replacement
    if [[ "$new_base" == "$base" ]]; then
        new_base=$(echo "$base" | sed "s/$LC_OLD_NAME/$LC_NEW_NAME/gi")
    fi
    
    if [[ "$new_base" != "$base" ]]; then
        new_path="$dir/$new_base"
        echo "Renaming: $path -> $new_path"
        mv "$path" "$new_path"
    fi
done < files_to_rename.txt

# Clean up
rm files_to_rename.txt

# Step 4: Rename the parent directory itself (if needed)
CURRENT_DIR=$(pwd)
PARENT_DIR=$(dirname "$CURRENT_DIR")
BASE_DIR=$(basename "$CURRENT_DIR")

if [[ "$BASE_DIR" == *"$OLD_NAME"* ]] || [[ "$(echo "$BASE_DIR" | tr '[:upper:]' '[:lower:]')" == *"$(echo "$OLD_NAME" | tr '[:upper:]' '[:lower:]')"* ]]; then
    # Create new directory name by replacing occurrences of old name
    NEW_DIR_NAME=$(echo "$BASE_DIR" | sed "s/$OLD_NAME/$NEW_NAME/g" | sed "s/$LC_OLD_NAME/$LC_NEW_NAME/gi")
    NEW_DIR_PATH="$PARENT_DIR/$NEW_DIR_NAME"
    
    echo "Renaming parent directory: $CURRENT_DIR -> $NEW_DIR_PATH"
    echo "The script will copy itself to the new location and then execute from there to complete the renaming."
    
    # Create a temp directory to hold scripts
    TEMP_DIR="$PARENT_DIR/.rename_temp"
    mkdir -p "$TEMP_DIR"
    
    # Copy the script to temp directory
    TEMP_SCRIPT_PATH="$TEMP_DIR/$SCRIPT_NAME"
    cp "$SCRIPT_PATH" "$TEMP_SCRIPT_PATH"
    chmod +x "$TEMP_SCRIPT_PATH"
    
    # Create a runner script that will:
    # 1. Move the directory
    # 2. Write a navigation helper script
    # 3. Provide instructions for navigating to the new directory
    RUNNER_SCRIPT="$TEMP_DIR/finish_rename.sh"
    NAVIGATE_SCRIPT="$PARENT_DIR/navigate_to_new_dir.sh"
    
    cat > "$RUNNER_SCRIPT" << EOL
#!/bin/bash
# Move the directory
mv "$CURRENT_DIR" "$NEW_DIR_PATH"

# Create a navigation helper script
cat > "$NAVIGATE_SCRIPT" << 'INNEREOF'
#!/bin/bash
# This script helps navigate to the renamed project directory
cd "$NEW_DIR_PATH"
echo "Now in the renamed project directory: \$(pwd)"
exec \$SHELL
INNEREOF

chmod +x "$NAVIGATE_SCRIPT"

# Remove temp directory
rm -rf "$TEMP_DIR"

echo ""
echo "==================================================================="
echo "Project renamed successfully from '$OLD_NAME' to '$NEW_NAME'!"
echo "The project directory has been renamed to: $NEW_DIR_NAME"
echo ""
echo "To navigate to the new directory, either:"
echo "1. Run:  cd $NEW_DIR_PATH"
echo "2. Or use the navigation script:  source $NAVIGATE_SCRIPT"
echo "==================================================================="
EOL
    
    chmod +x "$RUNNER_SCRIPT"
    
    echo "Executing final rename step..."
    exec "$RUNNER_SCRIPT"
else
    echo "Project renamed successfully from '$OLD_NAME' to '$NEW_NAME'!"
fi 