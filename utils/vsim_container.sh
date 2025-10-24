#!/usr/bin/env sh
#
# Copyright 2020 Tymoteusz Blazejczyk
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DOCKER_ARGUMENTS=$@
XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}

if [ -z "$CONTAINER_ENGINE" ]; then
    if command -v podman >/dev/null 2>&1; then
        CONTAINER_ENGINE=podman
    else
        CONTAINER_ENGINE=docker
    fi
fi

$CONTAINER_ENGINE run \
    -ti \
    --rm \
    --workdir ${HOME} \
    -e DISPLAY=${DISPLAY} \
    -v "/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    -v "${HOME}:${HOME}:rw" \
    -e XAUTHORITY=${XAUTHORITY} \
    -v "${XAUTHORITY}:${XAUTHORITY}:rw" \
    -v "/etc/group:/etc/group:ro" \
    -v "/etc/passwd:/etc/passwd:ro" \
    --entrypoint /bin/bash \
    registry.gitlab.com/tymonx/docker-modelsim \
    ${DOCKER_ARGUMENTS:+-c "$DOCKER_ARGUMENTS"}

    # This argument messses up with permisions
    # --user "$(id -u):$(id -g)" \
