#!/bin/sh
set -e

# if ! getent passwd appuser > /dev/null 2>&1; then
#     addgroup -g "$GID" appgroup
#     adduser -S -u "$UID" -G appgroup appuser
# fi

# chown -R appuser:appgroup /app

#chown -R nobody /app

./bin/migrate
$@
