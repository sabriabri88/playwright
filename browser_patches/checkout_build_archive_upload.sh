#!/bin/bash
set -e
set +x
set -o pipefail

if [[ ($1 == '--help') || ($1 == '-h') ]]; then
  echo "usage: $(basename "$0") [firefox-linux|firefox-win64|webkit-gtk|webkit-wpe|webkit-gtk-wpe|webkit-win64|webkit-mac-10.15] [-f|--force]"
  echo
  echo "Prepares checkout under browser folder, applies patches, builds, archives, and uploads if build is missing."
  echo "Script will bail out early if the build for the browser version is already present."
  echo
  echo "Pass -f to upload anyway."
  echo
  echo "NOTE: This script is safe to run in a cronjob - it aquires a lock so that it does not run twice."
  exit 0
fi

if [[ $# == 0 ]]; then
  echo "missing build flavor!"
  echo "try './$(basename "$0") --help' for more information"
  exit 1
fi

CURRENT_ARCH="$(uname -m)"
CURRENT_HOST_OS="$(uname)"
CURRENT_HOST_OS_VERSION=""
if [[ "$CURRENT_HOST_OS" == "Darwin" ]]; then
  CURRENT_HOST_OS_VERSION=$(sw_vers -productVersion | grep -o '^\d\+.\d\+')
elif [[ "$CURRENT_HOST_OS" == "Linux" ]]; then
  CURRENT_HOST_OS="$(bash -c 'source /etc/os-release && echo $NAME')"
  CURRENT_HOST_OS_VERSION="$(bash -c 'source /etc/os-release && echo $VERSION_ID')"
fi

BROWSER_NAME=""
BROWSER_DISPLAY_NAME=""
EXTRA_BUILD_ARGS=""
EXTRA_ARCHIVE_ARGS=""
BUILD_FLAVOR="$1"
BUILD_BLOB_NAME=""
EXPECTED_HOST_OS=""
EXPECTED_HOST_OS_VERSION=""
EXPECTED_ARCH="x86_64"
BUILDS_LIST="EXPECTED_BUILDS"

# ===========================
#    WINLDD COMPILATION
# ===========================
if [[ "$BUILD_FLAVOR" == "winldd-win64" ]]; then
  BROWSER_NAME="winldd"
  EXPECTED_HOST_OS="MINGW"
  BUILD_BLOB_NAME="winldd-win64.zip"


# ===========================
#    FFMPEG COMPILATION
# ===========================
elif [[ "$BUILD_FLAVOR" == "ffmpeg-mac" ]]; then
  BROWSER_NAME="ffmpeg"
  EXTRA_BUILD_ARGS="--mac --full"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="11.6"
  BUILD_BLOB_NAME="ffmpeg-mac.zip"
elif [[ "$BUILD_FLAVOR" == "ffmpeg-mac-arm64" ]]; then
  BROWSER_NAME="ffmpeg"
  EXTRA_BUILD_ARGS="--mac --full"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="11.6"
  EXPECTED_ARCH="arm64"
  BUILD_BLOB_NAME="ffmpeg-mac-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "ffmpeg-linux" ]]; then
  BROWSER_NAME="ffmpeg"
  EXTRA_BUILD_ARGS="--linux"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="ffmpeg-linux.zip"
elif [[ "$BUILD_FLAVOR" == "ffmpeg-linux-arm64" ]]; then
  BROWSER_NAME="ffmpeg"
  EXTRA_BUILD_ARGS="--cross-compile-linux-arm64"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="ffmpeg-linux-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "ffmpeg-cross-compile-win64" ]]; then
  BROWSER_NAME="ffmpeg"
  EXTRA_BUILD_ARGS="--cross-compile-win64"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="ffmpeg-win64.zip"

# ===========================
#    CHROMIUM COMPILATION
# ===========================
elif [[ "$BUILD_FLAVOR" == "chromium-win64" ]]; then
  BROWSER_NAME="chromium"
  EXTRA_BUILD_ARGS="--full --goma"
  EXPECTED_HOST_OS="MINGW"
  BUILD_BLOB_NAME="chromium-win64.zip"
elif [[ "$BUILD_FLAVOR" == "chromium-mac" ]]; then
  BROWSER_NAME="chromium"
  EXTRA_BUILD_ARGS="--full --goma"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="12.2"
  BUILD_BLOB_NAME="chromium-mac.zip"
elif [[ "$BUILD_FLAVOR" == "chromium-mac-arm64" ]]; then
  BROWSER_NAME="chromium"
  EXTRA_BUILD_ARGS="--arm64 --full --goma"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="12.2"
  BUILD_BLOB_NAME="chromium-mac-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "chromium-linux" ]]; then
  BROWSER_NAME="chromium"
  EXTRA_BUILD_ARGS="--full --goma"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="18.04"
  BUILD_BLOB_NAME="chromium-linux.zip"
elif [[ "$BUILD_FLAVOR" == "chromium-linux-arm64" ]]; then
  BROWSER_NAME="chromium"
  EXTRA_BUILD_ARGS="--arm64 --full --goma"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="chromium-linux-arm64.zip"

# ===========================
#    CHROMIUM-TIP-OF-TREE COMPILATION
# ===========================
elif [[ "$BUILD_FLAVOR" == "chromium-tip-of-tree-win64" ]]; then
  BROWSER_NAME="chromium-tip-of-tree"
  EXTRA_BUILD_ARGS="--full --goma"
  EXPECTED_HOST_OS="MINGW"
  BUILD_BLOB_NAME="chromium-tip-of-tree-win64.zip"
elif [[ "$BUILD_FLAVOR" == "chromium-tip-of-tree-mac" ]]; then
  BROWSER_NAME="chromium-tip-of-tree"
  EXTRA_BUILD_ARGS="--full --goma"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="12.2"
  BUILD_BLOB_NAME="chromium-tip-of-tree-mac.zip"
elif [[ "$BUILD_FLAVOR" == "chromium-tip-of-tree-mac-arm64" ]]; then
  BROWSER_NAME="chromium-tip-of-tree"
  EXTRA_BUILD_ARGS="--arm64 --full --goma"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="12.2"
  BUILD_BLOB_NAME="chromium-tip-of-tree-mac-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "chromium-tip-of-tree-linux" ]]; then
  BROWSER_NAME="chromium-tip-of-tree"
  EXTRA_BUILD_ARGS="--full --goma"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="18.04"
  BUILD_BLOB_NAME="chromium-tip-of-tree-linux.zip"
elif [[ "$BUILD_FLAVOR" == "chromium-tip-of-tree-linux-arm64" ]]; then
  BROWSER_NAME="chromium-tip-of-tree"
  EXTRA_BUILD_ARGS="--arm64 --full --goma"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="chromium-tip-of-tree-linux-arm64.zip"

# ===========================
#    CHROMIUM-WITH-SYMBOLS COMPILATION
# ===========================
elif [[ "$BUILD_FLAVOR" == "chromium-with-symbols-win64" ]]; then
  BROWSER_NAME="chromium"
  BROWSER_DISPLAY_NAME="chromium-with-symbols"
  EXTRA_BUILD_ARGS="--symbols --full --goma"
  EXPECTED_HOST_OS="MINGW"
  BUILD_BLOB_NAME="chromium-with-symbols-win64.zip"
  BUILDS_LIST="EXPECTED_BUILDS_WITH_SYMBOLS"
elif [[ "$BUILD_FLAVOR" == "chromium-with-symbols-mac" ]]; then
  BROWSER_NAME="chromium"
  BROWSER_DISPLAY_NAME="chromium-with-symbols"
  EXTRA_BUILD_ARGS="--symbols --full --goma"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="12.2"
  BUILD_BLOB_NAME="chromium-with-symbols-mac.zip"
  BUILDS_LIST="EXPECTED_BUILDS_WITH_SYMBOLS"
elif [[ "$BUILD_FLAVOR" == "chromium-with-symbols-mac-arm64" ]]; then
  BROWSER_NAME="chromium"
  BROWSER_DISPLAY_NAME="chromium-with-symbols"
  EXTRA_BUILD_ARGS="--arm64 --symbols --full --goma"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="12.2"
  BUILD_BLOB_NAME="chromium-with-symbols-mac-arm64.zip"
  BUILDS_LIST="EXPECTED_BUILDS_WITH_SYMBOLS"
elif [[ "$BUILD_FLAVOR" == "chromium-with-symbols-linux" ]]; then
  BROWSER_NAME="chromium"
  BROWSER_DISPLAY_NAME="chromium-with-symbols"
  EXTRA_BUILD_ARGS="--symbols --full --goma"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="18.04"
  BUILD_BLOB_NAME="chromium-with-symbols-linux.zip"
  BUILDS_LIST="EXPECTED_BUILDS_WITH_SYMBOLS"
elif [[ "$BUILD_FLAVOR" == "chromium-with-symbols-linux-arm64" ]]; then
  BROWSER_NAME="chromium"
  BROWSER_DISPLAY_NAME="chromium-with-symbols-arm64"
  EXTRA_BUILD_ARGS="--arm64 --symbols --full --goma"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="chromium-with-symbols-linux-arm64.zip"
  BUILDS_LIST="EXPECTED_BUILDS_WITH_SYMBOLS"

# ===========================
#    FIREFOX COMPILATION
# ===========================
elif [[ "$BUILD_FLAVOR" == "firefox-ubuntu-18.04" ]]; then
  BROWSER_NAME="firefox"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="18.04"
  BUILD_BLOB_NAME="firefox-ubuntu-18.04.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-ubuntu-20.04" ]]; then
  BROWSER_NAME="firefox"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="firefox-ubuntu-20.04.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-ubuntu-20.04-arm64" ]]; then
  BROWSER_NAME="firefox"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_ARCH="aarch64"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="firefox-ubuntu-20.04-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-ubuntu-22.04" ]]; then
  BROWSER_NAME="firefox"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="22.04"
  BUILD_BLOB_NAME="firefox-ubuntu-22.04.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-ubuntu-22.04-arm64" ]]; then
  BROWSER_NAME="firefox"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_ARCH="aarch64"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="22.04"
  BUILD_BLOB_NAME="firefox-ubuntu-22.04-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-debian-11" ]]; then
  BROWSER_NAME="firefox"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Debian"
  EXPECTED_HOST_OS_VERSION="11"
  BUILD_BLOB_NAME="firefox-debian-11.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-mac-11" ]]; then
  BROWSER_NAME="firefox"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="11.6"
  EXPECTED_ARCH="x86_64"
  BUILD_BLOB_NAME="firefox-mac-11.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-mac-11-arm64" ]]; then
  BROWSER_NAME="firefox"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="11.6"
  EXPECTED_ARCH="arm64"
  BUILD_BLOB_NAME="firefox-mac-11-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-win64" ]]; then
  BROWSER_NAME="firefox"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="MINGW"
  BUILD_BLOB_NAME="firefox-win64.zip"
  # This is the architecture that is set by mozilla-build bash.
  EXPECTED_ARCH="i686"


# ===============================
#    FIREFOX-BETA COMPILATION
# ===============================
elif [[ "$BUILD_FLAVOR" == "firefox-beta-ubuntu-18.04" ]]; then
  BROWSER_NAME="firefox-beta"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="18.04"
  BUILD_BLOB_NAME="firefox-beta-ubuntu-18.04.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-beta-ubuntu-20.04" ]]; then
  BROWSER_NAME="firefox-beta"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="firefox-beta-ubuntu-20.04.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-beta-ubuntu-20.04-arm64" ]]; then
  BROWSER_NAME="firefox-beta"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_ARCH="aarch64"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="firefox-beta-ubuntu-20.04-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-beta-ubuntu-22.04" ]]; then
  BROWSER_NAME="firefox-beta"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="22.04"
  BUILD_BLOB_NAME="firefox-beta-ubuntu-22.04.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-beta-ubuntu-22.04-arm64" ]]; then
  BROWSER_NAME="firefox-beta"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_ARCH="aarch64"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="22.04"
  BUILD_BLOB_NAME="firefox-beta-ubuntu-22.04-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-beta-debian-11" ]]; then
  BROWSER_NAME="firefox-beta"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Debian"
  EXPECTED_HOST_OS_VERSION="11"
  BUILD_BLOB_NAME="firefox-beta-debian-11.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-beta-mac-11" ]]; then
  BROWSER_NAME="firefox-beta"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="11.6"
  EXPECTED_ARCH="x86_64"
  BUILD_BLOB_NAME="firefox-beta-mac-11.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-beta-mac-11-arm64" ]]; then
  BROWSER_NAME="firefox-beta"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="11.6"
  EXPECTED_ARCH="arm64"
  BUILD_BLOB_NAME="firefox-beta-mac-11-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "firefox-beta-win64" ]]; then
  BROWSER_NAME="firefox-beta"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="MINGW"
  BUILD_BLOB_NAME="firefox-beta-win64.zip"
  # This is the architecture that is set by mozilla-build bash.
  EXPECTED_ARCH="i686"

# ===========================
#    WEBKIT COMPILATION
# ===========================
elif [[ "$BUILD_FLAVOR" == "webkit-debian-11" ]]; then
  BROWSER_NAME="webkit"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Debian"
  EXPECTED_HOST_OS_VERSION="11"
  BUILD_BLOB_NAME="webkit-debian-11.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-universal" ]]; then
  BROWSER_NAME="webkit"
  EXTRA_BUILD_ARGS="--full --universal"
  EXTRA_ARCHIVE_ARGS="--universal"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="webkit-linux-universal.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-ubuntu-18.04" ]]; then
  BROWSER_NAME="webkit"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="18.04"
  BUILD_BLOB_NAME="webkit-ubuntu-18.04.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-ubuntu-20.04" ]]; then
  BROWSER_NAME="webkit"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  BUILD_BLOB_NAME="webkit-ubuntu-20.04.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-ubuntu-20.04-arm64" ]]; then
  BROWSER_NAME="webkit"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="20.04"
  EXPECTED_ARCH="aarch64"
  BUILD_BLOB_NAME="webkit-ubuntu-20.04-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-ubuntu-22.04" ]]; then
  BROWSER_NAME="webkit"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="22.04"
  BUILD_BLOB_NAME="webkit-ubuntu-22.04.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-ubuntu-22.04-arm64" ]]; then
  BROWSER_NAME="webkit"
  EXTRA_BUILD_ARGS="--full"
  EXPECTED_HOST_OS="Ubuntu"
  EXPECTED_HOST_OS_VERSION="22.04"
  EXPECTED_ARCH="aarch64"
  BUILD_BLOB_NAME="webkit-ubuntu-22.04-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-win64" ]]; then
  BROWSER_NAME="webkit"
  EXPECTED_HOST_OS="MINGW"
  BUILD_BLOB_NAME="webkit-win64.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-mac-10.15" ]]; then
  BROWSER_NAME="webkit"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="10.15"
  BUILD_BLOB_NAME="webkit-mac-10.15.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-mac-12" ]]; then
  BROWSER_NAME="webkit"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="12.2"
  BUILD_BLOB_NAME="webkit-mac-12.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-mac-12-arm64" ]]; then
  BROWSER_NAME="webkit"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="12.2"
  EXPECTED_ARCH="arm64"
  BUILD_BLOB_NAME="webkit-mac-12-arm64.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-mac-11" ]]; then
  BROWSER_NAME="webkit"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="11.6"
  BUILD_BLOB_NAME="webkit-mac-11.zip"
elif [[ "$BUILD_FLAVOR" == "webkit-mac-11-arm64" ]]; then
  BROWSER_NAME="webkit"
  EXPECTED_HOST_OS="Darwin"
  EXPECTED_HOST_OS_VERSION="11.6"
  EXPECTED_ARCH="arm64"
  BUILD_BLOB_NAME="webkit-mac-11-arm64.zip"


# ===========================
#    Unknown input
# ===========================
else
  echo ERROR: unknown build flavor - "$BUILD_FLAVOR"
  exit 1
fi

if [[ -z "$BROWSER_DISPLAY_NAME" ]]; then
  BROWSER_DISPLAY_NAME="${BROWSER_NAME}"
fi

if [[ "$CURRENT_ARCH" != "$EXPECTED_ARCH" ]]; then
  echo "ERROR: cannot build $BUILD_FLAVOR"
  echo "  -- expected arch: $EXPECTED_ARCH"
  echo "  --  current arch: $CURRENT_ARCH"
  exit 1
fi

if [[ "$CURRENT_HOST_OS" != $EXPECTED_HOST_OS* ]]; then
  echo "ERROR: cannot build $BUILD_FLAVOR"
  echo "  -- expected OS: $EXPECTED_HOST_OS"
  echo "  --  current OS: $CURRENT_HOST_OS"
  exit 1
fi

if [[ "$CURRENT_HOST_OS_VERSION" != "$EXPECTED_HOST_OS_VERSION" ]]; then
  echo "ERROR: cannot build $BUILD_FLAVOR"
  echo "  -- expected OS Version: $EXPECTED_HOST_OS_VERSION"
  echo "  --  current OS Version: $CURRENT_HOST_OS_VERSION"
  exit 1
fi

if [[ $(uname) == MINGW* || "$(uname)" == MSYS* ]]; then
  ZIP_PATH="$PWD/archive-$BROWSER_NAME.zip"
  LOG_PATH="$PWD/log-$BROWSER_NAME.zip"
else
  ZIP_PATH="/tmp/archive-$BROWSER_NAME.zip"
  LOG_PATH="/tmp/log-$BROWSER_NAME.zip"
fi

if [[ -f "$ZIP_PATH" ]]; then
  echo "Archive $ZIP_PATH already exists - remove and re-run the script."
  exit 1
fi
trap "rm -rf ${ZIP_PATH}; rm -rf ${LOG_PATH}; cd $(pwd -P);" INT TERM EXIT
cd "$(dirname "$0")"
BUILD_NUMBER=$(head -1 ./$BROWSER_NAME/BUILD_NUMBER)
BUILD_BLOB_PATH="${BROWSER_NAME}/${BUILD_NUMBER}/${BUILD_BLOB_NAME}"
LOG_BLOB_NAME="${BUILD_BLOB_NAME%.zip}.log.gz"
LOG_BLOB_PATH="${BROWSER_NAME}/${BUILD_NUMBER}/${LOG_BLOB_NAME}"

# pull from upstream and check if a new build has to be uploaded.
if ! [[ ($2 == '-f') || ($2 == '--force') ]]; then
  if ./upload.sh "${BUILD_BLOB_PATH}" --check; then
    echo "Build is already uploaded - no changes."
    exit 0
  fi
else
  echo "Force-rebuilding the build."
fi

function generate_and_upload_browser_build {
  echo "-- preparing checkout"
  if ! ./prepare_checkout.sh $BROWSER_NAME; then
    return 20
  fi

  echo "-- cleaning"
  if ! ./$BROWSER_NAME/clean.sh; then
    return 21
  fi

  echo "-- building"
  if ! ./$BROWSER_NAME/build.sh $EXTRA_BUILD_ARGS; then
    return 22
  fi

  echo "-- archiving to $ZIP_PATH"
  if ! ./$BROWSER_NAME/archive.sh "$ZIP_PATH" $EXTRA_ARCHIVE_ARGS; then
    return 23
  fi

  echo "-- uploading"
  if ! ./upload.sh "$BUILD_BLOB_PATH" "$ZIP_PATH"; then
    return 24
  fi
  return 0
}

function create_roll_into_playwright_pr {
  curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token ${GH_TOKEN}" \
  --data '{"event_type": "roll_into_pw", "client_payload": {"browser": "'"$1"'", "revision": "'"$2"'"}}' \
  https://api.github.com/repos/microsoft/playwright/dispatches
}

BUILD_ALIAS="$BUILD_FLAVOR r$BUILD_NUMBER"
node send_telegram_message.js "$BUILD_ALIAS -- started"

if generate_and_upload_browser_build 2>&1 | ./sanitize_and_compress_log.js $LOG_PATH; then
  # Report successful build. Note: MINGW might not have `du` command.
  UPLOAD_SIZE=""
  if command -v du >/dev/null && command -v awk >/dev/null; then
    UPLOAD_SIZE="$(du -h "$ZIP_PATH" | awk '{print $1}') "
  fi
  node send_telegram_message.js "$BUILD_ALIAS -- ${UPLOAD_SIZE}uploaded"

  # Check if we uploaded the last build.
  (
    for i in $(cat "${BROWSER_NAME}/${BUILDS_LIST}"); do
      URL="https://playwright2.blob.core.windows.net/builds/${BROWSER_NAME}/${BUILD_NUMBER}/$i"
      if ! [[ $(curl -s -L -I "$URL" | head -1 | cut -f2 -d' ') == 200 ]]; then
        # Exit subshell
        echo "Missing build at ${URL}"
        exit
      fi
    done;
    LAST_COMMIT_MESSAGE=$(git log --format=%s -n 1 HEAD -- "./${BROWSER_NAME}/BUILD_NUMBER")
    node send_telegram_message.js "<b>${BROWSER_DISPLAY_NAME} r${BUILD_NUMBER} COMPLETE! ✅</b> ${LAST_COMMIT_MESSAGE}"
    if [[ "${BROWSER_DISPLAY_NAME}" != "chromium-with-symbols" ]]; then
      create_roll_into_playwright_pr $BROWSER_NAME $BUILD_NUMBER
    fi
  )
else
  RESULT_CODE="$?"
  if (( RESULT_CODE == 10 )); then
    FAILED_STEP="./download_gtk_and_wpe_and_zip_together.sh"
  elif (( RESULT_CODE == 11 )); then
    FAILED_STEP="./upload.sh"
  elif (( RESULT_CODE == 20 )); then
    FAILED_STEP="./prepare_checkout.sh"
  elif (( RESULT_CODE == 21 )); then
    FAILED_STEP="./clean.sh"
  elif (( RESULT_CODE == 22 )); then
    FAILED_STEP="./build.sh"
  elif (( RESULT_CODE == 23 )); then
    FAILED_STEP="./archive.sh"
  elif (( RESULT_CODE == 24 )); then
    FAILED_STEP="./upload.sh"
  else
    FAILED_STEP="<unknown step>"
  fi
  # Upload logs only in case of failure and report failure.
  ./upload.sh "${LOG_BLOB_PATH}" ${LOG_PATH} || true
  node send_telegram_message.js "$BUILD_ALIAS -- ${FAILED_STEP} failed! ❌ <a href='https://playwright.azureedge.net/builds/${LOG_BLOB_PATH}'>${LOG_BLOB_NAME}</a> -- <a href='$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID'>GitHub Action Logs</a>"
  exit 1
fi

