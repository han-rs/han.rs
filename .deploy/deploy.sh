#!/bin/bash

# Cloudflare Pages Deployment Helper Script

# =================== Function Definitions ===================

# Function: Install Rust toolchain
install_rust() {
  # If proxy is enabled, set rustup mirror source
  if [ "$ENABLE_PROXY" = true ]; then
    echo "Using rsproxy mirror for accelerating Rust toolchain download..."
    export RUSTUP_DIST_SERVER="https://rsproxy.cn"
    export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
    RUSTUP_INIT_SH="https://rsproxy.cn/rustup-init.sh"
  fi

  # Check if cache directory exists
  if [[ ! -d "$CACHE_DIR/cargo" || ! -d "$CACHE_DIR/rustup" ]]; then
    echo "Rust cache does not exist, installing (toolchain: $SETUP_RUST_TOOLCHAIN, profile: $SETUP_RUST_PROFILE)..."

    # -f ensures curl returns error on server errors
    curl --proto '=https' --tlsv1.2 -sSf "$RUSTUP_INIT_SH" | sh -s -- --default-toolchain "$SETUP_RUST_TOOLCHAIN" --profile "$SETUP_RUST_PROFILE" -y

    # Check if installation was successful
    if [ $? -ne 0 ]; then
      echo "Failed to install Rust"
      exit 1
    fi

    # Configure Cargo and cache installation files
    if [[ -d "$HOME/.cargo" && -d "$HOME/.rustup" ]]; then
      echo "$CARGO_CONFIG" >"$HOME/.cargo/config.toml"

      # If proxy is enabled, add rsproxy configuration
      if [ "$ENABLE_PROXY" = true ]; then
        echo "$CARGO_CONFIG_RSPROXY" >>"$HOME/.cargo/config.toml"
      fi

      # Create cache directories and copy files
      mkdir -p "$CACHE_DIR/cargo"
      mkdir -p "$CACHE_DIR/rustup"
      cp -r "$HOME/.cargo"/* "$CACHE_DIR/cargo/" || {
        echo "Failed to cache cargo directory"
        exit 1
      }
      cp -r "$HOME/.rustup"/* "$CACHE_DIR/rustup/" || {
        echo "Failed to cache rustup files"
        exit 1
      }
    else
      echo "$HOME/.cargo directory does not exist, installation may have failed"
      exit 1
    fi
  else
    # Restore Rust installation from cache
    echo "Restoring Rust environment from cache..."
    mkdir -p "$HOME/.cargo"
    mkdir -p "$HOME/.rustup"
    cp -r "$CACHE_DIR/cargo"/* "$HOME/.cargo/" || {
      echo "Failed to restore cargo cache"
      exit 1
    }
    cp -r "$CACHE_DIR/rustup"/* "$HOME/.rustup/" || {
      echo "Failed to restore rustup cache"
      exit 1
    }
    # Ensure correct file permissions
    chown -R "$(whoami):$(whoami)" "$HOME/.cargo"
    chown -R "$(whoami):$(whoami)" "$HOME/.rustup"
  fi

  # Load cargo environment variables
  . "$HOME/.cargo/env"

  # Set default Rust toolchain
  rustup default "$SETUP_RUST_TOOLCHAIN"
}

# Function: Install mdbook
install_mdbook() {
  # Check if mdbook needs to be reinstalled
  if [[ ! -f "$CACHE_DIR/bin/mdbook" || $(cat "$CACHE_DIR/bin/mdbook-cache-version" 2>/dev/null) != "$SETUP_MDBOOK_VERSION" ]]; then
    echo "Installing mdbook v$SETUP_MDBOOK_VERSION..."

    # Create a temporary directory
    temp_dir=$(mktemp -d) || {
      echo "Failed to create temporary directory"
      exit 1
    }

    echo "Downloading mdbook..."
    curl -L -f "${GITHUB_PROXY}https://github.com/rust-lang/mdBook/releases/download/v$SETUP_MDBOOK_VERSION/mdbook-v$SETUP_MDBOOK_VERSION-x86_64-unknown-linux-gnu.tar.gz" -o "$temp_dir/mdbook.tar.gz" || {
      echo "Failed to download mdbook"
      exit 1
    }

    echo "Extracting mdbook..."
    tar -xzf "$temp_dir/mdbook.tar.gz" -C "$temp_dir" || {
      echo "Failed to extract mdbook"
      exit 1
    }

    # Move to bin directory and set execution permission
    mv "$temp_dir/mdbook" "$CACHE_DIR/bin/" || {
      echo "Failed to move mdbook binary file"
      exit 1
    }

    chmod +x "$CACHE_DIR/bin/mdbook" || {
      echo "Failed to set executable permission for mdbook"
      exit 1
    }

    # Clean up temporary files
    rm -rf "$temp_dir"

    # Record the installed version
    echo "$SETUP_MDBOOK_VERSION" >"$CACHE_DIR/bin/mdbook-cache-version"

    echo "mdbook installation completed"
  else
    echo "Using cached mdbook"
  fi
}

# Function: Install mdbook
install_mdbook_utils() {
  # Check if mdbook needs to be reinstalled
  if [[ ! -f "$CACHE_DIR/bin/mdbook-utils" || $(cat "$CACHE_DIR/bin/mdbook-utils-cache-version" 2>/dev/null) != "$SETUP_MDBOOK_UTILS_VERSION" ]]; then
    echo "Installing mdbook-utils v$SETUP_MDBOOK_UTILS_VERSION..."

    # Create a temporary directory
    temp_dir=$(mktemp -d) || {
      echo "Failed to create temporary directory"
      exit 1
    }

    echo "Downloading mdbook-utils..."
    curl -L -f "${GITHUB_PROXY}https://github.com/hanyu-dev/mdbook-utils/releases/download/v$SETUP_MDBOOK_UTILS_VERSION/mdbook-utils-v$SETUP_MDBOOK_UTILS_VERSION-x86_64-unknown-linux-gnu.tar.gz" -o "$temp_dir/mdbook-utils.tar.gz" || {
      echo "Failed to download mdbook-utils"
      exit 1
    }

    echo "Extracting mdbook-utils..."
    tar -xzf "$temp_dir/mdbook-utils.tar.gz" -C "$temp_dir" || {
      echo "Failed to extract mdbook-utils"
      exit 1
    }

    # Move to bin directory and set execution permission
    mv "$temp_dir/mdbook-utils" "$CACHE_DIR/bin/" || {
      echo "Failed to move mdbook-utils binary file"
      exit 1
    }

    chmod +x "$CACHE_DIR/bin/mdbook-utils" || {
      echo "Failed to set executable permission for mdbook-utils"
      exit 1
    }

    # Clean up temporary files
    rm -rf "$temp_dir"

    # Record the installed version
    echo "$SETUP_MDBOOK_UTILS_VERSION" >"$CACHE_DIR/bin/mdbook-utils-cache-version"

    echo "mdbook-utils installation completed"
  else
    echo "Using cached mdbook-utils"
  fi
}

# =================== Default Settings ===================

# Script behavior control
# Exit immediately on error
set -e
# Exit if any command in a pipeline fails
set -o pipefail
# Print each command (for debugging)
set -x

# Rust related settings
SETUP_RUST=${SETUP_RUST:-true}
SETUP_RUST_TOOLCHAIN=${SETUP_RUST_TOOLCHAIN:-"nightly"}
SETUP_RUST_PROFILE=${SETUP_RUST_PROFILE:-"minimal"}
RUSTUP_INIT_SH="https://sh.rustup.rs"
CARGO_CONFIG="""
[net]
git-fetch-with-cli = true
"""

# Proxy settings
ENABLE_PROXY=${ENABLE_PROXY:-false}
GITHUB_PROXY=${GITHUB_PROXY:-""}
DEFAULT_GITHUB_PROXY="https://gh-proxy.com/"
CARGO_CONFIG_RSPROXY="""
# Mirror for China Mainland
[source.crates-io]
replace-with = 'rsproxy-sparse'
[source.rsproxy]
registry = 'https://rsproxy.cn/crates.io-index'
[source.rsproxy-sparse]
registry = 'sparse+https://rsproxy.cn/index/'
[registries.rsproxy]
index = 'https://rsproxy.cn/crates.io-index'
"""

# Cache settings
CACHE_DIR=${CACHE_DIR:-".cache"}
CLEAR_CACHE_DIR=false

# Other tools settings
SETUP_MDBOOK=${SETUP_MDBOOK:-false}
SETUP_MDBOOK_VERSION=${SETUP_MDBOOK_VERSION:-"0.4.48"}
SETUP_MDBOOK_UTILS=${SETUP_MDBOOK_UTILS:-false}
SETUP_MDBOOK_UTILS_VERSION=${SETUP_MDBOOK_UTILS_VERSION:-"0.1.4"}

# Custom command
CUSTOM_CMD=${CUSTOM_CMD:-""}

# =================== Parameter Parsing ===================

while [[ $# -gt 0 ]]; do
  case $1 in
  --no-install-rust)
    SETUP_RUST=false
    shift
    ;;
  --rust-toolchain)
    SETUP_RUST_TOOLCHAIN="$2"
    shift 2
    ;;
  --rust-profile)
    SETUP_RUST_PROFILE="$2"
    shift 2
    ;;
  --enable-proxy)
    ENABLE_PROXY=true
    shift
    ;;
  --install-mdbook=*)
    SETUP_MDBOOK=true
    SETUP_MDBOOK_VERSION="${1#*=}"
    shift
    ;;
  --install-mdbook)
    SETUP_MDBOOK=true
    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      SETUP_MDBOOK_VERSION="$2"
      shift
    fi
    shift
    ;;
  --install-mdbook-utils=*)
    SETUP_MDBOOK_UTILS=true
    SETUP_MDBOOK_UTILS_VERSION="${1#*=}"
    shift
    ;;
  --install-mdbook-utils)
    SETUP_MDBOOK_UTILS=true
    if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
      SETUP_MDBOOK_UTILS_VERSION="$2"
      shift
    fi
    shift
    ;;
  --cache-dir)
    CACHE_DIR="$2"
    shift 2
    ;;
  --clear-cache)
    CLEAR_CACHE_DIR=true
    shift
    ;;
  --execute-command)
    CUSTOM_CMD="$2"
    shift 2
    ;;
  *)
    echo "Unknown parameter: $1"
    exit 1
    ;;
  esac
done

# =================== Script Execution ===================

echo "RUST_LOG=$RUST_LOG"
echo "Current path=$(realpath ./)"

# Clean cache directory (if needed)
if [[ "$CLEAR_CACHE_DIR" = true && -d "$CACHE_DIR" ]]; then
  echo "Cleaning cache directory: $(realpath "$CACHE_DIR")"
  rm -rf "$CACHE_DIR"
fi

# Create cache directory
if [ ! -d "$CACHE_DIR" ]; then
  echo "Creating cache directory..."
  mkdir -p "$CACHE_DIR" || {
    echo "Failed to create cache directory"
    exit 1
  }
fi

# Install Rust (if needed)
if [ "$SETUP_RUST" = true ]; then
  install_rust
else
  echo "Skipping Rust installation"
fi

# Create bin directory
if [ ! -d "$CACHE_DIR/bin" ]; then
  mkdir -p "$CACHE_DIR/bin" || {
    echo "Failed to create bin directory"
    exit 1
  }
fi

if [ "$ENABLE_PROXY" = true ] && [ -z "$GITHUB_PROXY" ]; then
  GITHUB_PROXY="$DEFAULT_GITHUB_PROXY"
fi

# Install mdbook
if [ "$SETUP_MDBOOK" != false ]; then
  install_mdbook
fi

# Install mdbook-utils
if [ "$SETUP_MDBOOK_UTILS" != false ]; then
  install_mdbook_utils
fi

# Update PATH to make tools available
export PATH="$(realpath "$CACHE_DIR/bin"):$PATH"
echo "PATH=$PATH"

# Print version information
echo "======== VERSION INFO ========"
echo -n "Cargo: "
cargo --version || {
  echo "Failed to get cargo version"
  exit 1
}

echo -n "Rustup: "
rustup --version || {
  echo "Failed to get rustup version"
  exit 1
}

if [ "$SETUP_MDBOOK" != false ]; then
  echo -n "mdBook: "
  mdbook --version || {
    echo "Failed to get mdbook version"
    exit 1
  }
fi

if [ "$SETUP_MDBOOK_UTILS" != false ]; then
  echo -n "mdBook Utils: "
  mdbook-utils --version || {
    echo "Failed to get mdbook-utils version"
    exit 1
  }
fi
echo "========================="

# Execute custom command (if specified)
if [ -n "$CUSTOM_CMD" ]; then
  eval "$CUSTOM_CMD"

  # The following code is commented out but kept for reference
  # # Write back to cache
  # cp -r "$HOME/.cargo"/* "$CACHE_DIR/cargo/" || { echo "Failed to cache cargo directory"; exit 1; }
  # cp -r "$HOME/.rustup"/* "$CACHE_DIR/rustup/" || { echo "Failed to cache rustup files"; exit 1; }
fi
