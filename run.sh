#! /bin/bash

set -e

function run {
  python3 main.py
}

echo Run app in $APP_ENV environment
run