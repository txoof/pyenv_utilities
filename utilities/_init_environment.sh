#!/usr/bin/env bash

# Derive script and project directories
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"


# Extract project name from the parent directory
PROJECT_NAME="$(basename "$PROJECT_DIR")"


# Virtual environment name with hash for uniqueness
VENV_HASH=$(echo -n "$PROJECT_DIR" | md5sum | cut -c1-10)
VENV="$PROJECT_DIR/${PROJECT_NAME}-venv-$VENV_HASH"

KERNEL_SPEC="$PROJECT_DIR/.jupyter_kernelspec"
ACTIVATE_SL="$PROJECT_DIR/venv_activate"


# Function to handle script abortion
abort() {
  local message="$1"
  local exit_code="${2:-0}"
  if [[ -n "$message" ]]; then
    echo "$message"
  fi
  exit "$exit_code"
}

function help {
  cat << EOF

  Setup the virtual environment for this project

  Usage:
    $0 [option]

  Options:
    -c                Create the virtual environment (using venv by default)
    -j                Create the virtual environment AND add Jupyter kernel for development
    --pyenv <version> Create the virtual environment using pyenv with specified Python version 
                      -c or -j is required
    -h                Display this help screen
    -p                Purge the virtual environment and clean Jupyter kernelspecs
    --info            Display virtual environment information

EOF
  abort
}

# create a virtual environment using venv
function create_venv {    
    echo "Creating virtual environment in $VENV"
    if [ -f $VENV/bin/activate ]
    then
        echo "Virtual environment in $VENV exists, skipping this step"
    else
        pushd $PROJECT_DIR
        python3 -m venv $VENV
        popd
        ln -s $VENV/bin/activate $ACTIVATE_SL
    fi
}

function create_pyenv {    
    echo "Creating pyenv virtual environment in $PROJECT_DIR"
    if [ -f .python-version ];
    then
        echo "Pyenv virtual environment in $PROJECT_DIR exists, skipping this step"
    else
        echo "stuff here"
    fi
}

function jupyter_config {
  local venvName=$(basename "$VENV")
  if jupyter kernelspec list | grep -q "$venvName"; then
    echo "Jupyter kernel '$venvName' already exists. Skipping installation."
  else
    python -m ipykernel install --user --name "$venvName" --display-name "Python ($venvName)" || abort "Failed to install Jupyter kernel." 1
    echo "$venvName" > "$PROJECT_DIR/.jupyter_kernelspec"
    echo "Jupyter kernel installed with name '$venvName'."
  fi
}

# remove venv and purge kernelspec if it exists
function purge_venv {
  local venvName=$(basename "$VENV")

  # Confirm with the user before proceeding
  read -p "Are you sure you want to purge the virtual environment and related configurations? (y/N) " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Purge operation cancelled."
    return
  fi
  
  # Remove virtual environment directory if it exists
  if [[ -d "$VENV" ]]; then
    if [[ "$VENV" == *"${PROJECT_NAME}-venv-"* ]]; then
      echo "Removing virtual environment directory '$VENV'..."
      rm -rf "$VENV" || abort "Failed to remove virtual environment." 1
      echo "Virtual environment directory removed successfully."
    else
      echo "Error: The virtual environment path '$VENV' does not match the expected pattern. Aborting to prevent unintended deletion."
      return 1
    fi
  else
    echo "Virtual environment directory '$VENV' does not exist."
  fi

  # Remove Jupyter kernel spec if it exists
  if [[ -f "$KERNEL_SPEC" ]]; then
    local kernel_name=$(cat "$KERNEL_SPEC")
    if jupyter kernelspec list | grep -Fxq "$kernel_name"; then
      echo "Removing Jupyter kernel spec '$kernel_name'..."
      jupyter kernelspec remove "$kernel_name" -f || abort "Failed to remove Jupyter kernel spec." 1
      echo "Jupyter kernel spec removed successfully."
    else
      echo "Jupyter kernel spec '$kernel_name' does not exist or has already been removed."
    fi
  fi

  # Remove configuration file if it exists
  if [[ -f "$KERNEL_SPEC" ]]; then
    rm "$KERNEL_SPEC" || abort "Failed to remove configuration file." 1
  fi

 # Remove venv_activate symlink if it exists
  if [[ -L "$ACTIVATE_SL" ]]; then
    echo "Removing symlink '$ACTIVATE_SL'..."
    rm "$ACTIVATE_SL" || abort "Failed to remove symlink '$ACTIVATE_SL'." 1
    echo "Symlink '$ACTIVATE_SL' removed successfully."
  else
    echo "Symlink '$ACTIVATE_SL' does not exist."
  fi  
}



# Initialize variables for flags and values
pyenv=""
c_flag=0
h_flag=0
j_flag=0
p_flag=0

# Use getopts to parse flags and input values
while getopts "chjp-:" opt; do
  case $opt in
    c)
      if [[ $p_flag -eq 1 ]]; then
        abort "The -c and -p options are mutually exclusive." 1
      fi
      c_flag=1
      ;;
    h)
      help
      ;;
    j)
      if [[ $p_flag -eq 1 ]]; then
        abort "The -j and -p options are mutually exclusive." 1
      fi
      j_flag=1
      ;;
    p)
      if [[ $c_flag -eq 1 ]] || [[ $j_flag -eq 1 ]]; then
        abort "The -c|-j and -p options are mutually exclusive." 1
      fi
      p_flag=1
      ;;
    -)
      case "${OPTARG}" in
        pyenv)
          pyenv_version="${!OPTIND}"
          if [[ -z "$pyenv_version" ]]; then
            abort "The --pyenv option requires a version argument. Try '$ pyenv versions' for a list of locally available versions" 1
          fi
          OPTIND=$((OPTIND + 1))
          ;;
        *)
          abort "Invalid option: --${OPTARG}" 1
          ;;
      esac
      ;;
    *)
      help
      ;;
  esac
done

if [[ $c_flag -eq 0 && $j_flag -eq 0 && $p_flag -eq 0 ]]; then  
  help
fi

if [[ $c_flag -eq 1 ]] || [[ $j_flag -eq 1 ]]; then
  if [[ -n $pyenv_version ]]; then
    create_pyenv
  else
    create_venv
  fi
  if [[ $j_flag  -eq 1 ]]; then
    jupyter_config
  fi
fi

if [[ $p_flag -eq 1 ]]; then
  purge_venv
fi

if [[ -n $pyenv ]]; then
  echo "Pyenv value: $pyenv"
fi
