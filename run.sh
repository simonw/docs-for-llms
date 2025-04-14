#!/bin/bash
./build-docs.sh https://github.com/simonw/llm llm
./build-docs.sh https://github.com/simonw/datasette datasette
./build-docs.sh https://github.com/simonw/sqlite-utils sqlite-utils
./build-docs.sh https://github.com/simonw/shot-scraper shot-scraper
./build-docs.sh https://github.com/simonw/s3-credentials s3-credentials

# Datasette plugin writing documentation
./build-docs.sh https://github.com/simonw/datasette datasette-plugins \
  -f docs/plugins.rst \
  -f docs/plugin_hooks.rst \
  -f docs/testing_plugins.rst \
  -f docs/writing_plugins.rst \
  -f docs/internals.rst
