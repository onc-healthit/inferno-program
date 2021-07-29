#!/bin/bash
set -e

# Check available memory when running in docker
if [ -f /.dockerenv ]; then
  available_ram_kb=$(cat /proc/meminfo | grep MemTotal | sed -r 's/MemTotal:\s+([0-9]+)\skB/\1/')
  (( available_ram_gb=$available_ram_kb / 1000 / 1000 ))
  if (( $available_ram_gb < 10 )); then
    echo "10 GB of RAM must be available in order to process the terminology, but only $available_ram_gb GB are available"
    exit 1
  fi
fi

trap 'trap " " SIGTERM; kill 0; wait;' SIGHUP SIGINT SIGTERM SIGQUIT SIGKILL SIGTSTP

./bin/prepare_terminology.sh 2019 &
./bin/prepare_terminology.sh 2020 &
./bin/prepare_terminology.sh 2021 &

wait

exec bundle exec rake terminology:create_module_vs_validators["uscore_v3.1.1","preferred"]
exec bundle exec rake terminology:create_module_vs_validators["uscore_v3.1.1","preferred","2020","false"]
exec bundle exec rake terminology:create_module_vs_validators["uscore_v3.1.1","preferred","2021","false"]
