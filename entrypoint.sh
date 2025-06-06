#!/bin/bash

set -e

# validate subscription status
API_URL="https://agent.api.stepsecurity.io/v1/github/$GITHUB_REPOSITORY/actions/subscription"

# Set a timeout for the curl command (3 seconds)
RESPONSE=$(curl --max-time 3 -s -w "%{http_code}" "$API_URL" -o /dev/null) || true
CURL_EXIT_CODE=${?}

# Check if the response code is not 200
if [ $CURL_EXIT_CODE -ne 0 ] || [ "$RESPONSE" != "200" ]; then
  if [ -z "$RESPONSE" ] || [ "$RESPONSE" == "000" ] || [ $CURL_EXIT_CODE -ne 0 ]; then
    echo "Timeout or API not reachable. Continuing to next step."
  else
    echo "Subscription is not valid. Reach out to support@stepsecurity.io"
    exit 1
  fi
fi

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

echo '::group:: Installing woke ... https://github.com/get-woke/woke'
curl -sfL https://raw.githubusercontent.com/get-woke/woke/main/install.sh | sh -s -- -b "${TEMP_PATH}" "${INPUT_WOKE_VERSION}" 2>&1
echo '::endgroup::'


echo '::group:: Running woke with reviewdog 🐶 ...'
woke --output simple ${INPUT_WOKE_ARGS} \
  | reviewdog -efm="%f:%l:%c: %m" \
      -name="woke" \
      -reporter="${INPUT_REPORTER:-github-pr-check}" \
      -filter-mode="${INPUT_FILTER_MODE:-added}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR:-false}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_FLAGS}
echo '::endgroup::'
