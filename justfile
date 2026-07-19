# bumps the patch version in mix.exs
bump:
    #!/usr/bin/env bash
    set -euo pipefail

    old=$(grep -oP 'version: "\K[0-9.]+(?=")' mix.exs)
    major=$(echo "$old" | cut -d. -f1)
    minor=$(echo "$old" | cut -d. -f2)
    patch=$(echo "$old" | cut -d. -f3)

    if [ "$major" -ge 255 ] || [ "$minor" -ge 255 ] || [ "$patch" -ge 255 ]; then
        echo "ERROR: version components cannot exceed 255" >&2
        exit 1
    fi

    new="${major}.${minor}.$((patch + 1))"
    sed -i "s/version: \"$old\"/version: \"$new\"/" mix.exs
    echo "Bumped: ${old} -> ${new}"

# bumps the minor version in mix.exs
bump-minor:
    #!/usr/bin/env bash
    set -euo pipefail

    old=$(grep -oP 'version: "\K[0-9.]+(?=")' mix.exs)
    major=$(echo "$old" | cut -d. -f1)
    minor=$(echo "$old" | cut -d. -f2)

    if [ "$major" -ge 255 ] || [ "$minor" -ge 255 ]; then
        echo "ERROR: version components cannot exceed 255" >&2
        exit 1
    fi

    new="${major}.$((minor + 1)).0"
    sed -i "s/version: \"$old\"/version: \"$new\"/" mix.exs
    echo "Bumped: ${old} -> ${new}"

# bumps the major version in mix.exs
bump-major:
    #!/usr/bin/env bash
    set -euo pipefail

    old=$(grep -oP 'version: "\K[0-9.]+(?=")' mix.exs)
    major=$(echo "$old" | cut -d. -f1)

    if [ "$major" -ge 255 ]; then
        echo "ERROR: major version component cannot exceed 255" >&2
        exit 1
    fi

    new="$((major + 1)).0.0"
    sed -i "s/version: \"$old\"/version: \"$new\"/" mix.exs
    echo "Bumped: ${old} -> ${new}"
