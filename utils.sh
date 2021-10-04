#!/usr/bin/env bash

print() {
  printf "\033[34;1m▶\033[0m %s\n" "${1:-}" >/dev/stderr
}
