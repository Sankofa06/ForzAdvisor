#!/bin/zsh

set -u

profile_path=${1:-${RELEASE_RUNNER_PROFILE:-$HOME/.codex/release-runners/silversurfer-pro.json}}
failures=0
notices=0

pass() { print "PASS  $1"; }
fail() { print "FAIL  $1"; failures=$((failures + 1)); }
note() { print "NOTE  $1"; notices=$((notices + 1)); }

for command_name in jq ssh; do
  command -v "$command_name" >/dev/null 2>&1 && pass "$command_name is available" || fail "$command_name is unavailable"
done

if [[ ! -r "$profile_path" ]]; then
  fail "runner profile is not readable"
  print "SUMMARY failures=$failures notices=$notices"
  exit 1
fi

jq empty "$profile_path" >/dev/null 2>&1 && pass "runner profile is valid JSON" || fail "runner profile is invalid JSON"

profile=$(jq -r '.profile // empty' "$profile_path")
ssh_host=$(jq -r '.sshHost // empty' "$profile_path")
signing_metadata_path=$(jq -r '.signingMetadataPath // empty' "$profile_path")
workspace_root=$(jq -r '.workspaceRoot // empty' "$profile_path")
[[ "$workspace_root" == /tmp/* && "$workspace_root" != *'/../'* && "$workspace_root" != *'/..' ]] || { fail "runner workspace path is invalid"; print "SUMMARY failures=$failures notices=$notices"; exit 1; }
[[ -n "$profile" ]] && pass "runner profile: $profile" || fail "runner profile name is missing"
[[ -n "$ssh_host" ]] && pass "SSH alias is configured" || fail "SSH alias is missing"

if (( failures > 0 )); then
  print "SUMMARY failures=$failures notices=$notices"
  exit 1
fi

runner_facts=$(ssh -o LogLevel=QUIET -o BatchMode=yes -o ConnectTimeout=10 "$ssh_host" "/bin/zsh -s -- ${(q)signing_metadata_path} ${(q)workspace_root}" <<'REMOTE'
  set -u
  signing_metadata_path=$1
  workspace_root=$2
  selected_developer_dir=$(xcode-select -p 2>/dev/null || true)
  xcode_version=$(xcodebuild -version 2>/dev/null | awk "NR == 1 { print \$2 }")
  xcode_build=$(xcodebuild -version 2>/dev/null | awk "/Build version/ { print \$3 }")
  sdk_version=$(xcrun --sdk iphoneos --show-sdk-version 2>/dev/null || true)
  signing_state=unconfigured
  if [[ -n "$signing_metadata_path" ]]; then
    signing_state=missing
    if [[ "$signing_metadata_path" != /* && "$signing_metadata_path" != *../* ]]; then
      signing_metadata="$HOME/$signing_metadata_path"
      if [[ -r "$signing_metadata" ]] && jq empty "$signing_metadata" >/dev/null 2>&1; then
        keychain_path=$(jq -r '.keychainPath // empty' "$signing_metadata")
        password_file=$(jq -r '.passwordFile // empty' "$signing_metadata")
        profile_state=$(jq -r 'if (.profiles? | type) == "object" then (if ((.profiles | length) > 0 and ([.profiles[].profileState] | all(. == "ACTIVE"))) then "ACTIVE" else "INACTIVE" end) else (.profileState // empty) end' "$signing_metadata")
        if [[ "$keychain_path" == "$HOME"/Library/Keychains/* && -r "$keychain_path" && -r "$password_file" && "$profile_state" == ACTIVE ]]; then
          # The build helper validates the password while holding the serialized
          # release lock. Preflight must never leave a shared keychain unlocked.
          signing_state=configured
        else
          signing_state=incomplete
        fi
      fi
    else
      signing_state=invalid_path
    fi
  fi
  signing_count=$(security find-identity -v -p codesigning 2>/dev/null | awk "/valid identities found/ { print \$1 }")
  available_kib=$(df -Pk "$workspace_root" 2>/dev/null | awk "NR == 2 { print \$4 }")
  xcodebuild_count=$(pgrep -x xcodebuild 2>/dev/null | wc -l | tr -d "[:space:]")
  xctest_count=$(pgrep -x xctest 2>/dev/null | wc -l | tr -d "[:space:]")
  # Ignore the idle self-hosted Actions Runner.Listener; reject Fabricon task processes.
  fabricon_process_count=$(ps -axo comm | awk '/[Ff]abricon/ && $0 !~ /\/Runner\.Listener$/ { count++ } END { print count + 0 }')
  archive_lock=absent
  [[ ! -e "$workspace_root/.archive-upload.lock" ]] || archive_lock=present
  booted_simulator_names=$(xcrun simctl list devices booted -j 2>/dev/null | jq -c '[.devices[][]? | select(.state == "Booted") | .name]' 2>/dev/null || printf "[]")
  credentials_state=missing
  credentials_file="$HOME/.codex/secrets/app-store-connect.env"
  if [[ -r "$credentials_file" && "$(stat -f "%Lp" "$credentials_file" 2>/dev/null)" == 600 ]]; then
    credentials_state=ready
    for variable in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH; do
      if ! awk -v key="$variable" 'BEGIN{found=0} $0 ~ "^[[:space:]]*(export[[:space:]]+)?" key "=" {sub(/^[^=]*=/, ""); if (length($0)>0) found=1} END{exit found ? 0 : 1}' "$credentials_file"; then
        credentials_state=incomplete
      fi
    done
  fi
  printf "localHostName=%s\n" "$(scutil --get LocalHostName 2>/dev/null || true)"
  printf "remoteUser=%s\n" "$(id -un)"
  printf "architecture=%s\n" "$(uname -m)"
  printf "macOSVersion=%s\n" "$(sw_vers -productVersion 2>/dev/null || true)"
  printf "macOSBuild=%s\n" "$(sw_vers -buildVersion 2>/dev/null || true)"
  printf "developerDir=%s\n" "$selected_developer_dir"
  printf "xcodeVersion=%s\n" "$xcode_version"
  printf "xcodeBuild=%s\n" "$xcode_build"
  printf "iPhoneOSSDK=%s\n" "$sdk_version"
  printf "signingCount=%s\n" "${signing_count:-0}"
  printf "signingState=%s\n" "$signing_state"
  printf "availableKiB=%s\n" "${available_kib:-0}"
  printf "xcodebuildCount=%s\n" "${xcodebuild_count:-0}"
  printf "xctestCount=%s\n" "${xctest_count:-0}"
  printf "fabriconProcessCount=%s\n" "${fabricon_process_count:-0}"
  printf "archiveLock=%s\n" "$archive_lock"
  printf "bootedSimulatorNames=%s\n" "$booted_simulator_names"
  printf "credentials=%s\n" "$credentials_state"
REMOTE
)
ssh_status=$?
if (( ssh_status != 0 )); then
  fail "passwordless SSH connection failed"
  print "SUMMARY failures=$failures notices=$notices"
  exit 1
fi
pass "passwordless SSH connection succeeded"

fact_value() {
  print -r -- "$runner_facts" | awk -F= -v key="$1" '$1 == key { sub(/^[^=]*=/, ""); print; exit }'
}

for key in localHostName remoteUser architecture macOSVersion macOSBuild developerDir xcodeVersion xcodeBuild iPhoneOSSDK; do
  expected=$(jq -r --arg key "$key" '.expected[$key] // empty' "$profile_path")
  actual=$(fact_value "$key")
  if [[ -z "$expected" ]]; then
    fail "expected $key is missing from the runner profile"
  elif [[ "$actual" == "$expected" ]]; then
    pass "$key matches the configured runner profile"
  else
    fail "$key does not match the configured runner profile"
  fi
done

credentials_state=$(fact_value credentials)
[[ "$credentials_state" == ready ]] && pass "remote App Store Connect credential file is complete and mode 600" || fail "remote App Store Connect credential file is ${credentials_state:-missing}"

signing_count=$(fact_value signingCount)
signing_state=$(fact_value signingState)
available_kib=$(fact_value availableKiB)
if [[ "$available_kib" =~ '^[0-9]+$' ]] && (( available_kib >= 15 * 1024 * 1024 )); then
  pass "runner workspace has at least 15 GiB free"
else
  fail "runner workspace has less than 15 GiB free or disk capacity is unavailable"
fi

xcodebuild_count=$(fact_value xcodebuildCount)
[[ "$xcodebuild_count" == 0 ]] && pass "no competing xcodebuild process is active" || fail "a competing xcodebuild process is active"
xctest_count=$(fact_value xctestCount)
[[ "$xctest_count" == 0 ]] && pass "no competing xctest process is active" || fail "a competing xctest process is active"
archive_lock=$(fact_value archiveLock)
[[ "$archive_lock" == absent ]] && pass "stable-runner archive lock is absent" || fail "stable-runner archive lock is present"
fabricon_process_count=$(fact_value fabriconProcessCount)
[[ "$fabricon_process_count" == 0 ]] && pass "no Fabricon workload is active" || fail "a Fabricon workload is active"
booted_simulator_names=$(fact_value bootedSimulatorNames)
if [[ "$booted_simulator_names" == '["iPhone 17 Pro Max"]' ]]; then
  pass "the existing iPhone 17 Pro Max simulator remains booted"
elif [[ "$booted_simulator_names" == '[]' ]]; then
  note "no simulator is booted; simulator inventory will be left unchanged"
else
  note "current booted simulator inventory will be left unchanged"
fi

if [[ -n "$signing_metadata_path" && "$signing_state" != configured ]]; then
  fail "remote signing metadata is ${signing_state:-missing}"
elif [[ "${signing_count:-0}" == 0 ]]; then
  note "remote keychain has no valid code-signing identity; archive must use automatic signing or stop at the signing gate"
else
  pass "remote keychain reports $signing_count valid code-signing identity or identities"
fi

print "SUMMARY failures=$failures notices=$notices"
(( failures == 0 ))
