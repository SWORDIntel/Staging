# mkvenv: create & activate a Python3 virtual environment
# Usage: mkvenv [NAME]
# If NAME is omitted, defaults to ".venv"
mkvenv() {
    local VENV_NAME="${1:-.venv}"
    local PYTHON_CMD

    # Find a suitable python3
    if command -v python3 &>/dev/null; then
        PYTHON_CMD=python3
    elif command -v python &>/dev/null; then
        PYTHON_CMD=python
    else
        echo "Error: python3 not found in PATH." >&2
        return 1
    fi

    # Create the venv (resume if already exists)
    if [ -d "$VENV_NAME" ]; then
        echo "Virtualenv '$VENV_NAME' already exists. Skipping creation."
    else
        echo "Creating virtualenv '$VENV_NAME' with $PYTHON_CMD..."
        "$PYTHON_CMD" -m venv "$VENV_NAME" \
            && echo "✅ Virtualenv created." \
            || { echo "Error: failed to create virtualenv." >&2; return 2; }
    fi

    # Activate it
    if [ -f "$VENV_NAME/bin/activate" ]; then
        # shellcheck disable=SC1090
        source "$VENV_NAME/bin/activate"
        echo "Activated virtualenv '$VENV_NAME'."
    else
        echo "Error: activate script not found in '$VENV_NAME/bin/'." >&2
        return 3
    fi
}
