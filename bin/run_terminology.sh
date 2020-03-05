#!/bin/bash
set -e

temp_folder="tmp/terminology"

if [[ ! -f "$temp_folder/umls.zip" ]]; then
  [[ -z "$UMLS_USERNAME" ]] && { echo "UMLS Username environment variable is empty" >&2 ; exit 1; }
  [[ -z "$UMLS_PASSWORD" ]] && { echo "UMLS Password environment variable is empty" >&2 ; exit 1; }
  function control_c_download {
    kill -INT "$child"
    rm -f "$temp_folder/umls.zip"
    exit $?
  }
  trap control_c_download SIGHUP SIGINT SIGTERM SIGQUIT SIGKILL SIGTSTP
  bundle exec rake terminology:download_umls["$UMLS_USERNAME","$UMLS_PASSWORD"] &
  child=$!
  wait "$child"
else
  echo "UMLS Zip already exists; skipping UMLS download Rake task."
fi

if [[ ! -e "$temp_folder/umls" ]]; then
  function control_c_unzip {
    kill -INT "$child"
    rm -rf "$temp_folder/umls"
    exit $?
  }
  trap control_c_unzip SIGHUP SIGINT SIGTERM SIGQUIT SIGKILL SIGTSTP
  bundle exec rake terminology:unzip_umls &
  child=$!
  wait "$child"
else
  echo "UMLS Directory already exists; skipping UMLS Unzip Rake task."
fi

if [[ ! -e "$temp_folder/umls_subset" ]]; then
  function control_c_mmsys {
    kill -INT "$child"
    rm -rf "$temp_folder/umls_subset"
    exit $?
  }
  trap control_c_mmsys SIGHUP SIGINT SIGTERM SIGQUIT SIGKILL SIGTSTP
  bundle exec rake terminology:run_umls &
  child=$!
  wait "$child"
else
  echo "UMLS Subset already exists; skipping Metamorphosys Rake task."
fi

if [[ ! -f "$temp_folder/umls.db" ]]; then
  function control_c_db {
    kill -INT "$child"
    rm -f "$temp_folder/umls.db"
    rm -f "$temp_folder/MRCONSO.pipe"
    rm -f "$temp_folder/MRREL.pipe"
    rm -f "$temp_folder/MRSAT.pipe"
    exit $?
  }
  trap control_c_db SIGHUP SIGINT SIGTERM SIGQUIT SIGKILL SIGTSTP
  ./bin/create_umls.sh &
  child=$!
  wait "$child"
else
  echo "UMLS DB Already exists; skipping creation script."
fi

trap - SIGHUP SIGINT SIGTERM SIGQUIT SIGKILL SIGTSTP

exec bundle exec rake terminology:create_vs_validators
