#!/bin/sh

node node_modules/@digix/doxity/lib/bin/doxity.js build
echo 'docs.projectwyvern.com' > docs/CNAME
