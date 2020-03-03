#!/bin/bash

temp_folder="tmp/terminology"

if [[ ! -f "$temp_folder/umls.zip" ]]; then
  [[ -z "$UMLS_USERNAME" ]] && { echo "UMLS Username environment variable is empty" >&2 ; exit 1; }
  [[ -z "$UMLS_PASSWORD" ]] && { echo "UMLS Password environment variable is empty" >&2 ; exit 1; }
  bundle exec rake terminology:download_umls["$UMLS_USERNAME","$UMLS_PASSWORD"]
else
  echo "UMLS Zip already exists; skipping UMLS download Rake task."
fi

if [[ ! -e "$temp_folder/umls" ]]; then
  bundle exec rake terminology:unzip_umls
else
  echo "UMLS Directory already exists; skipping UMLS Unzip Rake task."
fi

if [[ ! -e "$temp_folder/umls_subset" ]]; then
  bundle exec rake terminology:run_umls
else
  echo "UMLS Subset already exists; skipping Metamorphosys Rake task."
fi

if [[ ! -f "$temp_folder/umls.db" ]]; then
  ./bin/create_umls.sh
else
  echo "UMLS DB Already exists; skipping creation script."
fi

bundle exec rake terminology:create_vs_validators
