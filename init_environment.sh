#!/usr/bin/env bash

VERSION="0.2.0"

# Derive script and project directories
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"


# Extract project name from the parent directory
PROJECT_NAME="$(basename "$PROJECT_DIR")"


# Virtual environment name with hash for uniqueness
VENV_HASH=$(echo -n "$PROJECT_DIR" | md5sum | cut -c1-10)
VENV="$PROJECT_DIR/${PROJECT_NAME}-venv-$VENV_HASH"
PYENV="${PROJECT_NAME}-pyenv-$VENV_HASH"

KERNEL_SPEC="$PROJECT_DIR/.jupyter_kernelspec"
ACTIVATE_SL="$PROJECT_DIR/venv_activate"

# List of files to ignore in .gitignore - quotated, spaces NO COMMAS

FILES_TO_IGNORE=("/$(basename "$VENV")" "venv_activate" ".jupyter_kernelspec")



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

  init_environment V$VERSION

  Setup a virtual environment for this project

  Usage:
    $0 [option]

  Options:
    -c                Create the virtual environment (using venv by default)
    -j                Create the virtual environment AND add Jupyter kernel for development
    --pyenv <version> Create the virtual environment using pyenv with specified Python version 
                      -c or -j is required
    -g                Update .gitignore to ignore venv related files                    
    -p                Purge the virtual environment and remove Jupyter kernelspecs
    -k                Purge only the jupyter kernelspecs for this project
    -h                Display this help screen
    -V                Display version information and exit

EOF
  abort
}


function git_ignore {
    local gitignore_file="$PROJECT_DIR/.gitignore"
    local start_marker="# BEGIN PYENV_UTILITIES MANAGED BLOCK"
    local end_marker="# END PYENV_UTILITIES MANAGED BLOCK"

    # Check if current directory is a git repository
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        # Create .gitignore if missing
        if [ ! -f "$gitignore_file" ]; then
            echo ".gitignore does not exist in $PROJECT_DIR. Creating .gitignore..."
            touch "$gitignore_file"
        fi

        # Remove the existing managed block if present
        if grep -q "$start_marker" "$gitignore_file"; then
            sed -i "/$start_marker/,/$end_marker/d" "$gitignore_file"
        fi

        # Add the managed block
        echo "Adding entries to .gitignore..."
        {
            echo "$start_marker"
            for file in "${FILES_TO_IGNORE[@]}"; do
                echo "$file"
            done
            echo "$end_marker"
        } >> "$gitignore_file"

        echo "Entries added to .gitignore."
    else
        echo "Current directory is not a git repository. Skipping .gitignore update."
    fi
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
    local venvName=$(basename "$PYENV")
    echo "Creating local pyenv virtual environment based on $pyenv_version named $venvName in $PROJECT_DIR"
    pushd $PROJECT_DIR
    if [ -f .python-version ];
    then
        echo "Local pyenv virtual environment in $PROJECT_DIR exists, skipping this step"
    else

        if ! command -v pyenv &> /dev/null 
        then
            popd
            abort "pyenv does not appear to be installed or in the path. Stopping." 1
        fi
    
        # Check to see if $pyenv_version is available locally, if not offer to install it
        if ! pyenv versions --skip-aliases | grep -q "$pyenv_version"; then
            echo "$pyenv_version is not available locally. Would you like to install it? (y/n)"
            read -r response
            if [[ "$response" == "y" ]]; then
                pyenv install "$pyenv_version"
            else
                abort "Pyenv version $pyenv_version is requed to continue. Exiting." 1
                popd
            fi
        fi # check for pyenv version

        # Create a pyenv virtualenv only if it does not exist
        if ! pyenv versions --skip-aliases | grep -q "$venvName"; then
            pyenv virtualenv "$pyenv_version" "$venvName"
            exit_status=$?
            if [[ $exit_status -ne 0 && $exit_status -ne 130 ]]; then
                abort "Failed to create pyenv virtual environment." 1
            fi
        else
            echo "Pyenv virtual environment $venvName already exists, skipping creation."
        fi
        pyenv local $venvName || abort "Failed to set local venv" 1
    fi # check for .python_version
    popd
}


function jupyter_config {

  echo "Configuring Jupyter..."
  local venvName=""
  if [[ -f .python-version ]]; then
     venvName=$PYENV
    if venv_activate ; then
      pip install ipykernel || abort "Failed to install ipykernel. Stopping." 1
    else
      echo "There appears to be a local pyenv version file, but no active virtual environment"
      echo "Cannot proceed with setting up Jupyter kernel."
      echo "Try re-running the script with the same command. If you see this same message, there is a larger problem"
      return
    fi  
  elif [[ -d $VENV ]]; then
    source $VENV/bin/activate || abort "Failed to activate virtual environment in $VENV. Stopping" 1
    venvName=$(basename "$VENV")
    if venv_active ; then
      pip install ipykernel || abort "Failed to install ipykernel. Stopping." 1
    fi
  fi

  if [[ -z $venvName ]]; then
    echo "Something went very wrong with determining the project virtual environment. Skipping jupyter configuration."
    echo "You can configure it manually with the following command:"
    echo "$ python -m ipykernel install --user --name <project_name_nere> --display-name \"Python (<project_name_here)\""
    return
  fi
  
  if jupyter kernelspec list | grep -q " $venvName "; then
    echo "Jupyter kernel '$venvName' already exists. Skipping installation."
  else
    python -m ipykernel install --user --name "$venvName" --display-name "Python ($venvName)" || abort "Failed to install Jupyter kernel." 1
    echo "$venvName" > "$PROJECT_DIR/.jupyter_kernelspec"
    echo "Jupyter kernel installed with name '$venvName'."
  fi
}

function purge_pyenv {
    local venvName=$(basename "$PYENV")
    local python_version="$PROJECT_DIR/.python-version"

    # Confirm with the user before proceeding
    read -p "Are you sure you want to purge the virtual environment and related configurations? (y/N) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Purge operation cancelled."
        return
    fi

    echo "Checking if pyenv virtual environment $venvName exists for purging."

    if ! command -v pyenv &> /dev/null 
    then
        echo "pyenv does not appear to be installed or in the path. Stopping." 1
        exit 1
    fi

    # Check if the pyenv virtual environment exists
    if [[ -f $python_version ]]
    then
        pyenv uninstall $venvName || abort "Failed to remove $venvName. Stopping." 1
        rm $python_version
    else
        echo "No local pyenv venvs found. Nothing to do."
        return
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

 # Remove venv_activate symlink if it exists
  if [[ -L "$ACTIVATE_SL" ]]; then
    echo "Removing symlink '$ACTIVATE_SL'..."
    rm "$ACTIVATE_SL" || abort "Failed to remove symlink '$ACTIVATE_SL'." 1
    echo "Symlink '$ACTIVATE_SL' removed successfully."
  else
    echo "Symlink '$ACTIVATE_SL' does not exist."
  fi  
}

function purge_kernelspec {
  # Remove Jupyter kernel spec if it exists

    if [[ -d $VENV ]]; then
      local kernel_name=$(basename "$VENV")
    elif [[ -f $PROJECT_DIR/.python-version ]]
    then
      local kernel_name=$PYENV
    fi
    
    if [[ -n $kernel_name ]]; then
      echo "Cleaning up any jupyter kernelspecs for $kernel_name"
      if jupyter kernelspec list | grep " $kernel_name "; then
          echo "Removing Jupyter kernel spec '$kernel_name'..."
          jupyter kernelspec remove "$kernel_name" -f || abort "Failed to remove Jupyter kernel spec." 1
          echo "Jupyter kernel spec removed successfully."
      else
          echo "No kernelspecs found to clean up. Check manually with 'jupyter kernelspec list'"
      fi
    fi

    # Remove configuration file if it exists
    if [[ -f "$KERNEL_SPEC" ]]; then
        rm "$KERNEL_SPEC" || abort "Failed to remove configuration file." 1
    fi    
    }

function purge {
    if [[ -d $VENV ]] 
    then
        echo "Cleaning up virtualenv $VENV"
        purge_venv
    elif [[ -f './.python-version' ]]
    then
        echo "Cleaning up pyenv local environment"
        purge_pyenv
    else
      echo "No venvs found to purge"
    fi
    purge_kernelspec
    echo "Done"
}

function install_requirements {
  echo "Activate your virtual environment and install requirements with 'pip install -r requirements.txt'"
}

# Initialize variables for flags and values
pyenv=""
c_flag=0
h_flag=0
j_flag=0
k_flag=0
p_flag=0

while getopts "chjkpVg-:" opt; do
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
    k)
      k_flag=1
      ;;
    p)
      if [[ $c_flag -eq 1 ]] || [[ $j_flag -eq 1 ]]; then
        abort "The -c|-j and -p options are mutually exclusive." 1
      fi
      p_flag=1
      ;;
    V)
      abort "$VERSION" 0
      ;;
    g)
      git_ignore
      abort
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
      echo "Unknown option"
      help
      ;;
  esac
done

if [[ $c_flag -eq 0 && $j_flag -eq 0 && $p_flag -eq 0 && $k_flag -eq 0 ]]; then  
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
  git_ignore
  install_requirements
fi

if [[ $k_flag -eq 1 ]]; then
  purge_kernelspec
fi

if [[ $p_flag -eq 1 ]]; then
  purge
fi

if [[ -n $pyenv ]]; then
  echo "Pyenv value: $pyenv"
fi
