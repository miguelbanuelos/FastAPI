#!/bin/bash
cd /docker/FastAPI
git config --global --add safe.directory /docker/FastAPI
git fetch --all
git reset --hard origin/main
docker compose up -d --build --force-recreate fastapi-api