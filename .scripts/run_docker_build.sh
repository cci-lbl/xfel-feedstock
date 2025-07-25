#!/usr/bin/env bash

# PLEASE NOTE: This script has been automatically generated by conda-smithy. Any changes here
# will be lost next time ``conda smithy rerender`` is run. If you would like to make permanent
# changes to this script, consider a proposal to conda-smithy so that other feedstocks can also
# benefit from the improvement.

source .scripts/logging_utils.sh

( startgroup "Configure Docker" ) 2> /dev/null

set -xeo pipefail

THISDIR="$( cd "$( dirname "$0" )" >/dev/null && pwd )"
PROVIDER_DIR="$(basename "$THISDIR")"

FEEDSTOCK_ROOT="$( cd "$( dirname "$0" )/.." >/dev/null && pwd )"
RECIPE_ROOT="${FEEDSTOCK_ROOT}/recipe"

if [ -z ${FEEDSTOCK_NAME} ]; then
    export FEEDSTOCK_NAME=$(basename ${FEEDSTOCK_ROOT})
fi

if [[ "${sha:-}" == "" ]]; then
  pushd "${FEEDSTOCK_ROOT}"
  sha=$(git rev-parse HEAD)
  popd
fi

docker info

# In order for the conda-build process in the container to write to the mounted
# volumes, we need to run with the same id as the host machine, which is
# normally the owner of the mounted volumes, or at least has write permission
export HOST_USER_ID=$(id -u)
# Check if docker-machine is being used (normally on OSX) and get the uid from
# the VM
if hash docker-machine 2> /dev/null && docker-machine active > /dev/null; then
    export HOST_USER_ID=$(docker-machine ssh $(docker-machine active) id -u)
fi

ARTIFACTS="$FEEDSTOCK_ROOT/build_artifacts"

if [ -z "$CONFIG" ]; then
    set +x
    FILES=`ls .ci_support/linux_*`
    CONFIGS=""
    for file in $FILES; do
        CONFIGS="${CONFIGS}'${file:12:-5}' or ";
    done
    echo "Need to set CONFIG env variable. Value can be one of ${CONFIGS:0:-4}"
    exit 1
fi

if [ -z "${DOCKER_IMAGE}" ]; then
    SHYAML_INSTALLED="$(shyaml -h || echo NO)"
    if [ "${SHYAML_INSTALLED}" == "NO" ]; then
        echo "WARNING: DOCKER_IMAGE variable not set and shyaml not installed. Trying to parse with coreutils"
        DOCKER_IMAGE=$(cat .ci_support/${CONFIG}.yaml | grep '^docker_image:$' -A 1 | tail -n 1 | cut -b 3-)
        if [ "${DOCKER_IMAGE}" = "" ]; then
            echo "No docker_image entry found in ${CONFIG}. Falling back to quay.io/condaforge/linux-anvil-comp7"
            DOCKER_IMAGE="quay.io/condaforge/linux-anvil-comp7"
        fi
    else
        DOCKER_IMAGE="$(cat "${FEEDSTOCK_ROOT}/.ci_support/${CONFIG}.yaml" | shyaml get-value docker_image.0 quay.io/condaforge/linux-anvil-comp7 )"
    fi
fi

mkdir -p "$ARTIFACTS"
DONE_CANARY="$ARTIFACTS/conda-forge-build-done-${CONFIG}"
rm -f "$DONE_CANARY"

# Allow people to specify extra default arguments to `docker run` (e.g. `--rm`)
DOCKER_RUN_ARGS="${CONDA_FORGE_DOCKER_RUN_ARGS}"
if [ -z "${CI}" ]; then
    DOCKER_RUN_ARGS="-it ${DOCKER_RUN_ARGS}"
fi

( endgroup "Configure Docker" ) 2> /dev/null

( startgroup "Start Docker" ) 2> /dev/null

export UPLOAD_PACKAGES="${UPLOAD_PACKAGES:-True}"
export IS_PR_BUILD="${IS_PR_BUILD:-False}"
docker pull "${DOCKER_IMAGE}"
docker run ${DOCKER_RUN_ARGS} \
           -v "${RECIPE_ROOT}":/home/conda/recipe_root:rw,z,delegated \
           -v "${FEEDSTOCK_ROOT}":/home/conda/feedstock_root:rw,z,delegated \
           -e CONFIG \
           -e HOST_USER_ID \
           -e UPLOAD_PACKAGES \
           -e IS_PR_BUILD \
           -e GIT_BRANCH \
           -e UPLOAD_ON_BRANCH \
           -e CI \
           -e FEEDSTOCK_NAME \
           -e CPU_COUNT \
           -e BUILD_WITH_CONDA_DEBUG \
           -e BUILD_OUTPUT_ID \
           -e flow_run_id \
           -e remote_url \
           -e sha \
           -e BINSTAR_TOKEN \
           "${DOCKER_IMAGE}" \
           bash \
           "/home/conda/feedstock_root/${PROVIDER_DIR}/build_steps.sh"

# verify that the end of the script was reached
test -f "$DONE_CANARY"

# This closes the last group opened in `build_steps.sh`
( endgroup "Final checks" ) 2> /dev/null
