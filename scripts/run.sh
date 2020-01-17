#!/bin/bash

# Thank you to github user urbantrout for these scripts, used from his craftCMS docker image.
# https://github.com/urbantrout

set -e

source /scripts/helpers.sh
source /scripts/plugins.sh

update_dependencies

wait

h2 "✅  Visit http://localhost or http://<docker-machine-ip> to start using Wordpress."

# start php-fpm
exec "$@"
