#!/usr/bin/env bash
#
# Smoke test for the antora-preview image.
#
# A successful `docker build` proves almost nothing about this image: every
# interesting part (Antora, Caddy, Ruby, guard and its plugins) only runs at
# container start. Base image bumps land here automatically via Renovate, so
# this script exists to actually start the thing and assert it works.
#
# Usage: test/smoke-test.sh [IMAGE]
#
# Environment:
#   PREVIEW_PORT     host port for the Caddy web server  (default 2020)
#   LIVERELOAD_PORT  host port for the LiveReload server (default 35729)
#   STARTUP_TIMEOUT  seconds to wait for the preview to come up (default 300)

set -euo pipefail

IMAGE="${1:-ghcr.io/vshn/antora-preview:latest}"
PREVIEW_PORT="${PREVIEW_PORT:-2020}"
LIVERELOAD_PORT="${LIVERELOAD_PORT:-35729}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-300}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINER="antora-preview-smoke-test-$$"
MARKER="ANTORA_PREVIEW_SMOKE_TEST_MARKER"

failures=0

pass() { printf '  ok   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; failures=$((failures + 1)); }

cleanup() {
  if docker inspect "$CONTAINER" >/dev/null 2>&1; then
    if [ "$failures" -ne 0 ]; then
      echo
      echo "--- container log ---"
      docker logs "$CONTAINER" 2>&1 | tail -n 100
      echo "--- end container log ---"
    fi
    docker rm --force "$CONTAINER" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "Smoke testing $IMAGE"
echo

# ---------------------------------------------------------------------------
# 1. Ruby dependencies resolve.
#
# This is the cheapest and most direct check. Guard swallows LoadErrors from
# its plugins and reports a confusing "undefined method 'ancestors' for true"
# instead, so assert the requires directly and get a real error message.
# Ruby 3.4 dropping base64 from the default gems broke exactly this path.
# ---------------------------------------------------------------------------
echo "Ruby dependencies"
for lib in guard guard/livereload guard/shell; do
  if docker run --rm --entrypoint ruby "$IMAGE" -e "require '$lib'" 2>/tmp/smoke-require.$$; then
    pass "require '$lib'"
  else
    fail "require '$lib'"
    grep -m 2 -E 'LoadError|cannot load such file|Error' /tmp/smoke-require.$$ \
      | sed 's/^/       /' || true
  fi
  rm -f /tmp/smoke-require.$$
done

# Ruby prints a deprecation warning before a gem is actually removed from the
# default gems. Surface it so the next removal is a warning, not an outage.
warnings="$(docker run --rm --entrypoint ruby "$IMAGE" \
  -e "require 'guard'; require 'guard/livereload'; require 'guard/shell'" 2>&1 \
  | grep -i 'not part of the default gems' || true)"
if [ -n "$warnings" ]; then
  echo "  WARN gem(s) scheduled for removal from Ruby's default gems:"
  echo "$warnings" | sed 's/^/       /'
  echo "       Add them to the gem install list in the Dockerfile."
fi
echo

# ---------------------------------------------------------------------------
# 2. The preview actually starts and serves the rendered fixture.
# ---------------------------------------------------------------------------
echo "Preview server"
docker run --detach --name "$CONTAINER" \
  --publish "${PREVIEW_PORT}:2020" \
  --publish "${LIVERELOAD_PORT}:35729" \
  --volume "${REPO_ROOT}:/preview/antora" \
  "$IMAGE" --antora=test/fixture --style=vshn >/dev/null

deadline=$((SECONDS + STARTUP_TIMEOUT))
ready=0
while [ "$SECONDS" -lt "$deadline" ]; do
  if ! docker inspect --format '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
    fail "container exited during startup"
    break
  fi
  if docker logs "$CONTAINER" 2>&1 | grep -q 'Guard is now watching'; then
    ready=1
    break
  fi
  sleep 2
done

if [ "$ready" -eq 1 ]; then
  pass "guard started (Guardfile evaluated, all plugins loaded)"
elif [ "$failures" -eq 0 ]; then
  fail "guard did not start within ${STARTUP_TIMEOUT}s"
fi

if [ "$ready" -eq 1 ]; then
  # Caddy serves the site Antora rendered. antora-preview.sh does not set -e,
  # so a failed Antora build still leaves Caddy serving an empty directory.
  # Assert on fixture content, not just on a 200.
  body="$(curl --silent --show-error --fail --max-time 30 \
    "http://localhost:${PREVIEW_PORT}/smoketest/index.html" 2>/dev/null || true)"
  if [ -z "$body" ]; then
    fail "no response from web server on port ${PREVIEW_PORT}"
  elif ! grep -q "$MARKER" <<<"$body"; then
    fail "web server responded but the fixture page was not rendered"
  else
    pass "fixture page rendered and served on port ${PREVIEW_PORT}"
  fi

  # antora-preview.sh rewrites the playbook's start page from antora.yml, so
  # the site root has to redirect into the component.
  if curl --silent --fail --max-time 30 --output /dev/null \
    "http://localhost:${PREVIEW_PORT}/" 2>/dev/null; then
    pass "site root serves the start page"
  else
    fail "site root does not serve the start page"
  fi

  # The UI bundle has to be unpacked into the site, otherwise the pages render
  # unstyled and the --style flag is silently doing nothing.
  if curl --silent --fail --max-time 30 --output /dev/null \
    "http://localhost:${PREVIEW_PORT}/_/css/site.css" 2>/dev/null; then
    pass "UI bundle assets served"
  else
    fail "UI bundle assets missing (/_/css/site.css)"
  fi

  # guard-livereload serves its client script over the same port it uses for
  # the websocket. If this answers, livereload really is listening.
  if curl --silent --fail --max-time 30 --output /dev/null \
    "http://localhost:${LIVERELOAD_PORT}/livereload.js" 2>/dev/null; then
    pass "livereload server listening on port ${LIVERELOAD_PORT}"
  else
    fail "livereload server not reachable on port ${LIVERELOAD_PORT}"
  fi
fi
echo

# ---------------------------------------------------------------------------
# 3. Nothing errored on the way up.
# ---------------------------------------------------------------------------
echo "Container log"
errors="$(docker logs "$CONTAINER" 2>&1 \
  | grep -E ' - ERROR - |"level":"error"|Could not load|cannot load such file' || true)"
if [ -n "$errors" ]; then
  fail "errors in container log:"
  echo "$errors" | head -n 20 | sed 's/^/       /'
else
  pass "no errors logged"
fi

# Antora reports missing pages, broken xrefs and unresolved start pages as
# warnings and still exits 0, so a clean HTTP response is not enough.
antora_warnings="$(docker logs "$CONTAINER" 2>&1 \
  | grep -E '"name":"@antora/' | grep -E '"level":"(warn|error|fatal)"' || true)"
if [ -n "$antora_warnings" ]; then
  fail "Antora reported problems building the fixture:"
  echo "$antora_warnings" | head -n 20 | sed 's/^/       /'
else
  pass "Antora built the fixture without warnings"
fi
echo

if [ "$failures" -ne 0 ]; then
  echo "smoke test FAILED (${failures} failure(s))"
  exit 1
fi
echo "smoke test passed"
