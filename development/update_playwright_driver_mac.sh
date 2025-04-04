#!/bin/sh

# Usage:
#   ./development/update_playwright_driver.sh 1.14.0-next-1628583854000
#
# Available versions can be found in https://github.com/microsoft/playwright/actions/workflows/publish_canary_driver.yml
#
# NOTE: direnv is assumed to be installed.

DRIVER_VERSION=$1
DRIVER_DOWNLOAD_DIR=~/Downloads

echo "## Downloading driver"

wget https://playwright.azureedge.net/builds/driver/next/playwright-$DRIVER_VERSION-mac.zip -O __driver.zip || wget https://playwright.azureedge.net/builds/driver/playwright-$DRIVER_VERSION-mac.zip -O __driver.zip

echo "## Extracting driver"

mv __driver.zip $DRIVER_DOWNLOAD_DIR/
pushd $DRIVER_DOWNLOAD_DIR/
unzip __driver.zip -d playwright-$DRIVER_VERSION-mac
rm __driver.zip
DRIVER_PATH=$(pwd)/playwright-$DRIVER_VERSION-mac/playwright.sh
popd

echo "## Setting PLAYWRIGHT_CLI_EXECUTABLE_PATH($DRIVER_PATH) into .envrc"

echo "export PLAYWRIGHT_CLI_EXECUTABLE_PATH=$DRIVER_PATH" > .envrc
direnv allow .

echo "## Updating API docs"

$DRIVER_PATH print-api-json | jq > development/api.json
# $DRIVER_PATH --version | cut -d' ' -f2 > development/CLI_VERSION
echo $DRIVER_VERSION > development/CLI_VERSION

echo "## Updating auto-gen codes"

rm lib/playwright_api/*.rb
find documentation/docs -name "*.md" | grep -v documentation/docs/article/ | xargs rm
bundle exec ruby development/generate_api.rb

echo "## Downloading browsers"

$DRIVER_PATH install
