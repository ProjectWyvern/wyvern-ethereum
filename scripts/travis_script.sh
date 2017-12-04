#!/usr/bin/env bash

set -e

yarn coverage

yarn testrpc &
sleep 1

yarn test
