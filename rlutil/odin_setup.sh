#!/bin/bash

# This script installs Odin, including its dependencies, on Linux and macOS.
OS="$(uname -s)"

install_dependencies() {
  if [[ "$OS" == "Linux" ]]; then
    echo "Detected Linux. Updating apt package list and installing clang..."
    # Update package lists
    sudo apt update
    sudo apt install -y clang
  elif [[ "$OS" == "Darwin" ]]; then
    echo "Detected macOS. Checking for Homebrew and installing clang..."
    # Check if Homebrew is installed.
    if ! command -v brew &> /dev/null; then
      echo "Homebrew is not installed. Please install Homebrew first by running the following command:"
      echo "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      echo "After installing Homebrew, please run this script again."
      exit 1 # Exit if Homebrew is not found
    fi
    brew update
    brew install clang
  else
    echo "Unsupported operating system: $OS"
    exit 1
  fi
}

install_dependencies

echo "Cloning the Odin repository..."
git clone https://github.com/odin-lang/Odin
cd Odin || { echo "Error: Failed to change directory to 'Odin'. Exiting."; exit 1; }

echo "Building Odin from source - this may take a minute..."
make release-native

// Update system PATH to include Odin
current_dir="$(pwd)"
profile_file=""
if [[ "$OS" == "Linux" ]]; then
  profile_file="$HOME/.bashrc"
elif [[ "$OS" == "Darwin" ]]; then
  if [[ -f "$HOME/.zshrc" ]]; then
    profile_file="$HOME/.zshrc"
  elif [[ -f "$HOME/.bash_profile" ]]; then
    profile_file="$HOME/.bash_profile"
  else
    profile_file="$HOME/.bashrc"
  fi
fi

# Check if a profile file was determined
if [[ -n "$profile_file" ]]; then
  # Check if the Odin path is already present in the profile file to prevent duplicates
  if ! grep -q "export PATH=\"${current_dir}:\$PATH\"" "$profile_file"; then
    echo "Adding Odin's binary directory to PATH in $profile_file..."
    echo "export PATH=\"${current_dir}:\$PATH\"" >> "$profile_file"
    echo "PATH updated. For the changes to take effect in your current terminal session,"
    echo "please run 'source $profile_file' or simply restart your terminal."
  else
    echo "Odin's path already exists in $profile_file. No changes made to PATH."
  fi
else
  echo "Warning: Could not determine appropriate shell profile file to update PATH."
  echo "Please add '${current_dir}' to your system's PATH manually."
fi
echo "--- Odin Install Complete ---"
echo "You are now able to use 'odin'"
