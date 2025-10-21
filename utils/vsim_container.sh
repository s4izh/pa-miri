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

podman run \
    --rm \
    --tty \
    --interactive \
    --user "$(id -u):$(id -g)" \
    --volume "${HOME}:${HOME}:rw" \
    --env DISPLAY=$DISPLAY \
    --env XAUTHORITY=$XAUTHORITY \
    --volume "/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --volume "$XAUTHORITY:$XAUTHORITY:rw" \
    --entrypoint /bin/bash \
    registry.gitlab.com/tymonx/docker-modelsim \
    ${DOCKER_ARGUMENTS:+-c "$DOCKER_ARGUMENTS"}


    # --volume "/etc/group:/etc/group:ro" \
    # --volume "/etc/passwd:/etc/passwd:ro" \
