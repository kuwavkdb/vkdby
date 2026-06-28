#!/usr/bin/env bash
# exit on error
set -o errexit

# Install jemalloc for reduced memory fragmentation
if ! dpkg -s libjemalloc2 > /dev/null 2>&1; then
  sudo apt-get update -qq && sudo apt-get install -yq libjemalloc2
fi

bundle install
bundle exec rails tailwindcss:build
bundle exec rails assets:precompile
bundle exec rails assets:clean
