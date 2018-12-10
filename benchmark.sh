#!/usr/bin/env bash

cd "$( dirname "${BASH_SOURCE[0]}" )"

echo `pwd`

find benchmark/ -maxdepth 1 -type f -name "*_benchmark.rb" -exec bundle exec ruby {} \;
