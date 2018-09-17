#!/bin/bash

pulp-admin login -u $1 -p $2

pulp-admin iso repo uploads upload --dir rocknsm-iso --repo-id rocknsm-nightly --bg
