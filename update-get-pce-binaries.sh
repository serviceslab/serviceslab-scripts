#!/bin/bash
# update-get-pce-binaries.sh
# This script dynamically generates a get-pce-binaries.sh script that downloads
# the latest Illumio PCE, UI, compatibility, and VEN packages based on available versions.

# Create or overwrite the target script with a shebang and initial setup
# Write to tmp script
temp_target_script=${target_script/.sh/.tmp}
cat <<EOF > "$temp_target_script"
#!/bin/bash
# get-pce-binaries.sh
cd /
EOF

# Fetch the latest available compatibility matrix
latest_compat_build=$(curl -s "https://$repo_compatibility/" | grep -oP 'href="\K[0-9]+(?=/")' | sort -nr | head -n1)
if [[ -n "$latest_compat_build" ]]; then
    compat_file=$(curl -s "https://$repo_compatibility/$latest_compat_build/" | grep -oP 'illumio-release-compatibility-[0-9]+-[0-9]+\.tar\.bz2' | sort -V | tail -n1)
    if [[ -n "$compat_file" ]]; then
        compat_url="https://$repo_compatibility/$latest_compat_build/$compat_file"
        echo "$compat_url"
    fi
fi

# Get a sorted list of all available major.minor version directories
major_minor_list=$(curl -s "https://$repo/" | grep -oP 'href="\K[0-9]+\.[0-9]+(?=/")' | sort --version-sort --unique)

# Flag to help format the if/elif block in the output script
first_if_statement=true

# Loop through each major.minor version
for major_minor_version in $major_minor_list; do
    ga_url="https://$repo/$major_minor_version/GA%20Releases/"
    
    # Get all available patch versions for this major.minor
    patch_list=$(curl -s "$ga_url" | grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+(?=/")' | sort --version-sort --unique)

    for patch in $patch_list; do
        echo "Processing version $patch..."

        # Construct package URLs
        pkgs_url="https://$repo/$major_minor_version/GA%20Releases/$patch/pce/pkgs/"
        
        # Fetch the latest PCE and UI packages
        pce_pkg=$(curl -s "$pkgs_url" | grep -oP 'illumio-pce-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.el9\.x86_64\.rpm' | sort --version-sort | tail --lines=1)
        ui_pkg=$(curl -s "${pkgs_url}UI/" | grep -oP 'illumio-pce-ui-[0-9]+\.[0-9]+\.[0-9]+\.UI[0-9]-[0-9]+\.x86_64\.rpm' | sort --version-sort | tail --lines=1)

        # Skip if either the PCE or UI package is missing
        if [[ -z "$pce_pkg" || -z "$ui_pkg" ]]; then
            echo "Skipping - missing PCE or UI package"
            continue
        fi

        # Look for matching VEN bundles from current or up to 3 major versions behind
        ven_bundles=()
        current_major=${major_minor_version%%.*}
        current_minor=${major_minor_version##*.}
        current_major_int=$((10#$current_major))
        current_minor_int=$((10#$current_minor))
        minimum_major=$((current_major_int - 3))

        for nested_major_minor_version in $major_minor_list; do
            nested_major=${nested_major_minor_version%%.*}
            nested_minor=${nested_major_minor_version##*.}
            nested_major_int=$((10#$nested_major))
            nested_minor_int=$((10#$nested_minor))

            # Check if nested version is within range (same or up to 3 major versions behind)
            if (( nested_major_int >= minimum_major )); then
                if (( nested_major_int < current_major_int )) || { (( nested_major_int == current_major_int )) && (( nested_minor_int <= current_minor_int )); }; then
                    ven_path="$repo/$nested_major_minor_version/GA%20Releases/"
                    nested_patch_list=$(curl -s "$ven_path" | grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+(?=/")' | sort --version-sort --unique --reverse)
                    
                    for nested_patch in $nested_patch_list; do
                        ven_url="$ven_path$nested_patch/ven/bundle/"
                        file=$(curl -s "https://$ven_url" | grep -oP 'illumio-ven-bundle-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.tar\.bz2' | sort --unique | head -n1)
                        
                        if [[ -n "$file" ]]; then
                            ven_patch=$(echo "$file" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
                            # Check that VEN version is <= current PCE patch
                            if [[ "$(printf "%s\n%s" "$patch" "$ven_patch" | sort -V | head -n1)" == "$ven_patch" ]]; then
                                full_url="https://$ven_url$file"
                                ven_bundles+=("$full_url")
                                break
                            fi
                        fi
                    done
                fi
            fi
        done

        # Output sorted list of VEN bundle URLs
        printf "%s\n" "${ven_bundles[@]}" | sort --unique

        # Write the conditional download block into the target script
        if $first_if_statement; then
            echo "if [[ \$pce_version == \"$patch\" ]]; then" >> "$temp_target_script"
            first_if_statement=false
        else
            echo "elif [[ \$pce_version == \"$patch\" ]]; then" >> "$temp_target_script"
        fi

        cat <<EOF >> "$temp_target_script"
  curl --remote-name https://$repo/$major_minor_version/GA%20Releases/$patch/pce/pkgs/$pce_pkg
  curl --remote-name https://$repo/$major_minor_version/GA%20Releases/$patch/pce/pkgs/UI/$ui_pkg
  curl --silent --remote-name $compat_url &
EOF

        for bundle in "${ven_bundles[@]}"; do
            echo "  curl -silent --remote-name ${bundle} &" >> "$temp_target_script"
        done
    done
done

# Close the final if-block and return to home directory
cat <<EOF >> "$temp_target_script"
fi
cd
EOF

# Make the generated script executable
cp "$temp_target_script" "$target_script"
chmod +x "$target_script"
echo "Done updating $target_script"
