# pyenv_utilities

Python virtual environment utilities for bootstrapping a virtual environment and optionally installing Jupyter kernels for use with Jupyter lab/notebook or VS Code. The `init_environment.sh` script will create a new virtual environment using the currently active python environment by default. Optionally, the script can also create a pyenv environment using a specific python version if required.

This script does the following:

- Creates a virtual environment (or pyenv) in the root of the project directory
- Creates and installs a Jupyter kerenl (optional)
- Creates a symbolic link for activating the virtual environment (only necessary for venv, pyenv uses shims to automagically activate the environment)
- Adds the virtual environment to `.gitignore` (only for git environments)

## General Usage

```help
  Setup a virtual environment for this project

  Usage:
    $0 [option]

  Options:
    -c                Create the virtual environment (using venv by default)
    -j                Create the virtual environment AND add Jupyter kernel for development
    --pyenv <version> Create the virtual environment using pyenv with specified Python version 
                      -c or -j is required
    -p                Purge the virtual environment and clean Jupyter kernelspecs
    -k                Purge jupyter kernelspecs for this project
    -h                Display this help screen
```

The `pyenv_utilities` directory should reside within your existing project folder:

```text
📁 my_project ← project root
├─ README.md
├─ requirements.txt
├─ 📁 project_files ← project files
│  ├─ foo.py
│  └─ foo.ipynb
│
├─ 📁 pyenv_utilities
│  └─ init_environment.sh
└─ 📁 my_project-VENV-d98f0 ← generated virtual environment
```

### Quick Start

The fastest way to get started is to add this repository as a submodule to an existing git repo to clone the utility into `./pyenv_utilities`:

```bash
$ cd ~/src/foobar_project

$ git submodule add https://github.com/txoof/pyenv_utilities.git

Cloning into '/Users/spamham/Documents/src/foobar_test/pyenv_utilities'...
remote: Enumerating objects: 48, done.
remote: Counting objects: 100% (48/48), done.
remote: Compressing objects: 100% (34/34), done.
remote: Total 48 (delta 23), reused 34 (delta 12), pack-reused 0 (from 0)
Receiving objects: 100% (48/48), 177.56 KiB | 5.22 MiB/s, done.
Resolving deltas: 100% (23/23), done.
```

And then run: `$ ./pyenv_utilities -c` to create a virtual environment.

Alternatively, [download the project as a zip](https://github.com/txoof/pyenv_utilities/archive/refs/heads/main.zip) and decompress it in your project directory.

#### Recipes
______

**Create a virtual environment using your system/global python installation from your project directory:**

```bash
$ ./pyenv_utilities/init_environment.sh -c

Creating virtual environment in /Users/spamham/Documents/src/foobar_project/foobar_project-venv-cb9cd69576
~/Documents/src/foobar_project ~/Documents/src/foobar_project
~/Documents/src/foobar_project
Activate your virtual environment and install requirements with 'pip install -r requirements.txt'
```

**Create a virtual environment and add a Jupyter kernelspec:**

```bash
$ ./pyenv_utilities/init_environment.sh -j

Creating virtual environment in /Users/spamham/Documents/src/foobar_project/foobar_project-venv-cb9cd69576
~/Documents/src/foobar_project ~/Documents/src/foobar_project
~/Documents/src/foobar_project
Configuring Jupyter...
Collecting ipykernel
  Using cached ipykernel-6.29.5-py3-none-any.whl.metadata (6.3 kB)
...

Installed kernelspec foobar_project-venv-cb9cd69576 in /Users/spamham/Library/Jupyter/kernels/foobar_project-venv-cb9cd69576
Jupyter kernel installed with name 'foobar_project-venv-cb9cd69576'.
Activate your virtual environment and install requirements with 'pip install -r requirements.txt'
```

**Create a virtual environment using a specific python version using pyenv and install a kernelspec:**

```bash
$ ./pyenv_utilities/init_environment.sh -j --pyenv 3.9.17

Creating local pyenv virtual environment based on 3.9 named foobar_project-pyenv-cb9cd69576 in /Users/spamham/Documents/src/foobar_project
~/Documents/src/foobar_project ~/Documents/src/foobar_project
Looking in links: /var/folders/_3/sg55ynns5dzdyg3bcf4r8qzr0000gn/T/tmp2wd7eil6
Requirement already satisfied: setuptools in /Users/spamham/.pyenv/versions/3.9.20/envs/foobar_project-pyenv-cb9cd69576/lib/python3.9/site-packages (58.1.0)
Requirement already satisfied: pip in /Users/spamham/.pyenv/versions/3.9.20/envs/foobar_project-pyenv-cb9cd69576/lib/python3.9/site-packages (23.0.1)
~/Documents/src/foobar_project
```

**Purge a virtual environment and associated kernelspec:**

```bash
$ ./pyenv_utilities/init_environment.sh -p
Cleaning up virtualenv /Users/spamham/Documents/src/foobar_project/foobar_project-venv-cb9cd69576
Are you sure you want to purge the virtual environment and related configurations? (y/N) y
Removing virtual environment directory '/Users/spamham/Documents/src/foobar_project/foobar_project-venv-cb9cd69576'...
Virtual environment directory removed successfully.
Removing symlink '/Users/spamham/Documents/src/foobar_project/venv_activate'...
Symlink '/Users/spamham/Documents/src/foobar_project/venv_activate' removed successfully.
Done
```

Further reading on [Git Submodules](https://medium.com/@osinpaul/deep-dive-into-git-submodules-managing-dependencies-in-your-projects-b4847c83f34d)

## Update `pyenv_utilities`

```bash
$ git submodule update --remote --recursive --init
```

## Requirements

### Basic requirements

`python3` with `virtualenv`

### Requirements for pyenv functionality

`pyenv` with `pyenv-virtualenv`

**Note**, `pyenv` and `pyenv-virtualenv` are only available for \*nix/BSD environments<sup>1</sup>. Both can be installed with homebrew on Mac OS.

<sup>1</sup> [Pyenv does not officially support Windows or WSL](https://github.com/pyenv/pyenv?tab=readme-ov-file#windows), but @kirankotari's [pyenv-win fork](https://github.com/pyenv-win/pyenv-win), which does install native Windows Python versions, may be an option. This is untested and not supported with this script. YMMV.
