#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
bundle exec rails tailwindcss:build
bundle exec rails assets:precompile
bundle exec rails assets:clean

if [ "$IMPORT_DATA" = "true" ]; then
  echo "Running data import..."
  bundle exec rails db:migrate # Ensure DB is migrated before import
  bundle exec rails import:units
  bundle exec rails import:people
fi
