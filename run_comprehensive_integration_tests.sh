#!/bin/sh

set -e
set -x

echo DEPLOY_TO=$DEPLOY_TO
prove tests/integration/ratified/ tests/integration/sample/ tests/integration/config_rules/ tools/test-log.pl
