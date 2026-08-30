#!/bin/sh

GOVERNANCE_TEMPLATE_VERSION=0.1.0
DEFAULT_BRANCH=main
MAX_HEADER_LENGTH=72
COMMIT_TYPES='feat fix docs refactor perf test style build ci chore revert'
BRANCH_PATTERN='^codex/(feat|fix|docs|refactor|perf|test|style|build|ci|chore|revert)/[a-z0-9]+(-[a-z0-9]+)*$'
COMMIT_HEADER_PATTERN='^(feat|fix|docs|refactor|perf|test|style|build|ci|chore|revert)(\([a-z0-9]+(-[a-z0-9]+)*\))?!?: [a-z0-9].*$'
FORMAT_STAGED_ADAPTER=.governance/adapters/format-staged
FAST_CHECK_ADAPTER=.governance/adapters/check-fast
FULL_CHECK_ADAPTER=.governance/adapters/check-full
BUILD_RELEASE_ADAPTER=.governance/adapters/build-release
VERIFY_RELEASE_ADAPTER=.governance/adapters/verify-release
PRIVATE_REMOTE_ENFORCEMENT=unavailable
RELEASE_MODE=atomic
RELEASE_PLATFORMS='source'

