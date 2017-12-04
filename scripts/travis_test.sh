#!/usr/bin/env bash

set -e

yarn testrpc &
sleep 1
yarn test
