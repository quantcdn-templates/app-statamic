#!/bin/bash
# Laravel needs its storage tree at boot. On Quant Cloud, /var/www/html/storage
# is a persistent volume that starts empty and hides the directories baked into
# the image, so recreate them on every start (mkdir -p is a no-op once present).
set -e
for d in framework/views framework/cache/data framework/sessions logs app/public; do
  mkdir -p "/var/www/html/storage/$d"
done
chown -R www-data:www-data /var/www/html/storage
chmod -R 775 /var/www/html/storage
echo "[statamic] storage directories ready"
