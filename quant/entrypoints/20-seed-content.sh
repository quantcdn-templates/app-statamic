#!/bin/bash
# Seed the persistent content and users volumes from the image on first boot.
# Both start empty on Quant Cloud and hide the files shipped in src/. Only an
# empty directory is seeded, so edits made through the control panel survive.
set -e
for d in content users; do
  target="/var/www/html/$d"
  if [ -z "$(ls -A "$target" 2>/dev/null)" ]; then
    echo "[statamic] seeding empty $target from the image"
    cp -a "/usr/src/statamic-seed/$d/." "$target/"
  fi
  chown -R www-data:www-data "$target"
done
