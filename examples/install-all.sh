#! /usr/bin/env bash

set -euo pipefail

BULLET_EXAMPLES_VERSION=0.3.3
BULLET_UI_VERSION=0.3.2
BULLET_WS_VERSION=0.0.1
JETTY_VERSION=9.3.16.v20170120
STORM_VERSION=1.0.3
NVM_VERSION=0.33.1
NODE_VERSION=6.9.4

println() {
    local DATE
    DATE="$(date)"
    printf "%s [BULLET-QUICKSTART] %s\n" "${DATE}" "$1"
}

print_versions() {
    println "Using the following artifacts..."
    println "Bullet Examples:    ${BULLET_EXAMPLES_VERSION}"
    println "Bullet Web Service: ${BULLET_WS_VERSION}"
    println "Bullet UI:          ${BULLET_UI_VERSION}"
    println "Jetty:              ${JETTY_VERSION}"
    println "Storm:              ${STORM_VERSION}"
    println "NVM:                ${NVM_VERSION}"
    println "Node.js:            ${NODE_VERSION}"
    println "Done!"
}

download() {
    local URL="$1"
    local FILE="$2"

    local FILE_PATH="${BULLET_DOWNLOADS}/${FILE}"

    if [[ -s "${FILE_PATH}" ]]; then
        println "Download exists in ${FILE_PATH}. Skipping download..."
    else
        cd "${BULLET_DOWNLOADS}" && { curl --retry 2 -#LO "${URL}/${FILE}" ; cd - &> /dev/null; }
    fi
}

export_vars() {
    local PWD
    PWD="$(pwd)"

    println "Exporting some variables..."
    export BULLET_HOME="${PWD}/bullet-quickstart"
    export BULLET_EXAMPLES=$BULLET_HOME/bullet-examples
    export BULLET_DOWNLOADS=$BULLET_HOME/bullet-downloads
    println "Done!"
}

setup() {
    println "Setting up directories..."
    mkdir -p "${BULLET_HOME}/backend/storm"
    mkdir -p "${BULLET_HOME}/service"
    mkdir -p "${BULLET_HOME}/ui"
    mkdir -p "${BULLET_DOWNLOADS}"
    println "Done!"
}

install_bullet_examples() {
    println "Downloading Bullet Examples ${BULLET_EXAMPLES_VERSION}..."
    download "https://github.com/yahoo/bullet-docs/releases/download/v${BULLET_EXAMPLES_VERSION}" "examples_artifacts.tar.gz"

    println "Installing Bullet Examples..."
    tar -xzf "${BULLET_DOWNLOADS}/examples_artifacts.tar.gz" -C "${BULLET_HOME}"
    println "Done!"
}

install_storm() {
    local STORM="apache-storm-${STORM_VERSION}"
    local BACKEND="${BULLET_HOME}/backend/"

    println "Downloading Storm ${STORM_VERSION}..."
    download "http://apache.org/dist/storm/${STORM}" "${STORM}.zip"

    println "Installing Storm ..."
    unzip -qq "${BULLET_DOWNLOADS}/${STORM}.zip" -d "${BACKEND}"

    println "Configuring Storm ..."
    export PATH="${BACKEND}/${STORM}/bin/:${PATH}"
    echo 'drpc.servers: ["127.0.0.1"]' >> "${BACKEND}/${STORM}/conf/storm.yaml"
    println "Done!"
}

launch_storm() {
    println "Launching Storm Dev Zookeeper..."
    storm dev-zookeeper &

    println "Launching Storm Nimbus..."
    storm nimbus &

    println "Launching Storm DRPC..."
    storm drpc &

    println "Launching Storm UI..."
    storm ui &

    println "Launching Storm LogViewer..."
    storm logviewer &

    println "Launching a Storm Supervisor..."
    storm supervisor &

    println "Sleeping for 60 s to ensure all components are up..."
    println "=============================================================================="
    sleep 60
    println "=============================================================================="
    println "Done!"
}

launch_bullet_storm() {
    println "Copying Bullet topology configuration and artifacts..."
    cp "${BULLET_EXAMPLES}/storm"/* "${BULLET_HOME}/backend/storm"

    println "Launching the Bullet topology..."
    println "=============================================================================="
    cd "${BULLET_HOME}/backend/storm" && ./launch.sh
    println "=============================================================================="
    println "Done!"
    println "Sleeping for 30 s to ensure all Bullet Storm components are up..."
    println "=============================================================================="
    sleep 30
    println "=============================================================================="

    println "Testing the Storm topology"
    println ""
    println "Getting one random record from the Bullet topology..."
    curl -s -X POST -d '{}' http://localhost:3774/drpc/bullet
    println "Done!"
}

install_jetty() {
    local SERVICE="${BULLET_HOME}/service"
    local JETTY_DISTRIBUTION="jetty-distribution-${JETTY_VERSION}.zip"

    println "Downloading Jetty ${JETTY_VERSION}..."
    download "http://central.maven.org/maven2/org/eclipse/jetty/jetty-distribution/${JETTY_VERSION}" "${JETTY_DISTRIBUTION}"

    println "Installing Jetty..."
    unzip -qq "${BULLET_DOWNLOADS}/${JETTY_DISTRIBUTION}" -d "${SERVICE}"
    println "Done!"
}

launch_bullet_web_service() {
    local BULLET_WS_WAR="bullet-service-${BULLET_WS_VERSION}.war"
    local JETTY_INSTALLATION="${BULLET_HOME}/service/jetty-distribution-${JETTY_VERSION}"

    println "Downloading Bullet Web Service ${BULLET_WS_VERSION}..."
    download "http://jcenter.bintray.com/com/yahoo/bullet/bullet-service/${BULLET_WS_VERSION}" "${BULLET_WS_WAR}"

    println "Configuring Bullet Web Service..."
    cp "${BULLET_DOWNLOADS}/${BULLET_WS_WAR}" "${JETTY_INSTALLATION}/webapps/bullet-service.war"
    cp "${BULLET_EXAMPLES}/web-service/"example_* "${JETTY_INSTALLATION}"

    println "Launching Bullet Web Service..."
    cd "${JETTY_INSTALLATION}"
    java -jar -Dbullet.service.configuration.file="example_context.properties" -Djetty.http.port=9999 start.jar > logs/out 2>&1 &

    println "Sleeping for 30 s to ensure Bullet Web Service is up..."
    sleep 30

    println "Testing the Web Service"
    println ""
    println "Getting one random record from Bullet through the Web Service..."
    curl -s -X POST -d '{}' http://localhost:9999/bullet-service/api/drpc
    println ""
    println "Getting column schema from the Web Service..."
    println ""
    curl -s http://localhost:9999/bullet-service/api/columns
    println "Finished Bullet Web Service test"
}

install_node() {
    # NVM unset var bug
    set +u

    println "Trying to install nvm. If there is a failure, manually perform: "
    println "    curl -s https://raw.githubusercontent.com/creationix/nvm/v${NVM_VERSION}/install.sh | bash"
    println "    nvm install v${NODE_VERSION}"
    println "    nvm use v${NODE_VERSION}"
    println "and then try this script again..."

    println "Downloading and installing NVM ${NVM_VERSION}..."
    curl --retry 2 -s "https://raw.githubusercontent.com/creationix/nvm/v${NVM_VERSION}/install.sh" | bash

    println "Loading nvm into current environment if installation successful..."
    [ -s "${HOME}/.nvm/nvm.sh" ] && source "${HOME}/.nvm/nvm.sh"
    println "Done!"

    println "Installing Node ${NODE_VERSION}..."
    nvm install "v${NODE_VERSION}"
    nvm use "v${NODE_VERSION}"

    set -u

    println "Done!"
}

launch_bullet_ui() {
    local BULLET_UI_ARCHIVE="bullet-ui-v${BULLET_UI_VERSION}.tar.gz"

    println "Downloading Bullet UI ${BULLET_UI_VERSION}..."
    download "https://github.com/yahoo/bullet-ui/releases/download/v${BULLET_UI_VERSION}" "${BULLET_UI_ARCHIVE}"

    cd "${BULLET_HOME}/ui"

    println "Installing Bullet UI..."
    tar -xzf "${BULLET_DOWNLOADS}/${BULLET_UI_ARCHIVE}"

    println "Configuring Bullet UI..."
    cp "${BULLET_EXAMPLES}/ui/env-settings.json" config/

    println "Launching Bullet UI..."
    PORT=8800 node express-server.js &

    println "Sleeping for 5 s to ensure Bullet UI is up..."
    sleep 5
    println "Done!"
}

cleanup() {
    set +e

    pkill -f "[a]pache-storm-${STORM_VERSION}"
    pkill -f "[e]xpress-server.js"
    pkill -f "[e]xample_context.properties"

    sleep 3

    rm -rf "${BULLET_EXAMPLES}" "${BULLET_HOME}/backend" "${BULLET_HOME}/service" \
           "${BULLET_HOME}/ui" /tmp/dev-storm-zookeeper /tmp/jetty-*

    set -e
}

teardown() {
    println "Killing and cleaning up all Bullet components..."
    cleanup &> /dev/null
    println "Done!"
}

unset_all() {
    unset -f print_versions println download export_vars setup \
             install_bullet_examples \
             install_storm launch_storm launch_bullet_storm \
             install_jetty launch_bullet_web_service \
             install_node launch_bullet_ui \
             cleanup teardown unset_all launch
}

launch() {
    print_versions
    export_vars

    teardown

    setup
    install_bullet_examples

    install_storm
    launch_storm
    launch_bullet_storm

    install_jetty
    launch_bullet_web_service

    install_node
    launch_bullet_ui

    println "All components launched! Visit http://localhost:8800 (default) for the UI"
    unset_all
}

clean() {
    println "Launching cleanup..."
    export_vars
    teardown
    println "Not deleting ${BULLET_DOWNLOADS}, ${HOME}/.nvm or nvm additions to ${HOME}/{.profile, .bash_profile, .zshrc, .bashrc}..."
    println "Cleaned up ${BULLET_HOME} and /tmp"
    println "To delete all download artifacts (excluding nvm), do:"
    println "    rm -rf ${BULLET_HOME}"
    unset_all
}

if [ $# -eq 0 ]; then
    launch
else
    clean
fi