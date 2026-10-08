#!/bin/zsh

set -u
set -o pipefail

profile_path=${RELEASE_RUNNER_PROFILE:-$HOME/.codex/release-runners/silversurfer-pro.json}
platform=iOS
action=build
upload=0
upload_confirmation=
expected_version=
expected_build=
keep_remote=0

usage() {
  print "Usage: ssh_runner_build.sh [--profile FILE] [--platform iOS|macOS] [--archive --expected-version VERSION --expected-build BUILD] [--validate-signing] [--upload --confirm-upload TOKEN] [--keep-remote] REPO 40_CHAR_COMMIT"
}

require_option_value() {
  [[ $# -ge 2 && -n "$2" ]] || { usage; exit 2; }
}

while (( $# > 0 )); do
  case "$1" in
    --profile) require_option_value "$@"; profile_path=$2; shift 2 ;;
    --platform) require_option_value "$@"; platform=$2; shift 2 ;;
    --archive) action=archive; shift ;;
    --validate-signing) action=validate-signing; shift ;;
    --upload) upload=1; shift ;;
    --confirm-upload) require_option_value "$@"; upload_confirmation=$2; shift 2 ;;
    --expected-version) require_option_value "$@"; expected_version=$2; shift 2 ;;
    --expected-build) require_option_value "$@"; expected_build=$2; shift 2 ;;
    --keep-remote) keep_remote=1; shift ;;
    --help|-h) usage; exit 0 ;;
    --*) usage; exit 2 ;;
    *) break ;;
  esac
done

if (( $# != 2 )); then
  usage
  exit 2
fi
if (( upload == 1 )) && [[ "$action" != archive ]]; then
  print "FAIL  --upload requires --archive"
  exit 2
fi

repo_path=${1:A}
release_commit=$2
script_dir=${0:A:h}
committed_config=
generated_project_root=

cleanup_local() {
  if [[ -n "$committed_config" && "$committed_config" == /tmp/codex-release-config-* ]]; then
    rm -f -- "$committed_config"
  fi
  if [[ -n "$generated_project_root" && "$generated_project_root" == /tmp/codex-release-generated-* ]]; then
    rm -rf -- "$generated_project_root"
  fi
  return 0
}
trap cleanup_local EXIT

[[ "$release_commit" =~ '^[0-9a-fA-F]{40}$' ]] || { print "FAIL  release commit must be exactly 40 hexadecimal characters"; exit 2; }
[[ "$platform" == iOS || "$platform" == macOS ]] || { print "FAIL  platform must be iOS or macOS"; exit 2; }
[[ -d "$repo_path/.git" || -f "$repo_path/.git" ]] || { print "FAIL  repository is not a Git worktree"; exit 2; }
git -C "$repo_path" cat-file -e "$release_commit^{commit}" 2>/dev/null || { print "FAIL  release commit is unavailable locally"; exit 2; }
canonical_commit=$(git -C "$repo_path" rev-parse "$release_commit^{commit}" 2>/dev/null) || { print "FAIL  release commit could not be resolved"; exit 2; }
canonical_commit=${canonical_commit:l}
if (( upload == 1 )) && [[ "$release_commit" != "$canonical_commit" ]]; then
  print "FAIL  upload requires the lowercase canonical 40-character commit"
  exit 2
fi
git -C "$repo_path" cat-file -e "${canonical_commit}:.gitmodules" 2>/dev/null && { print "FAIL  repositories with submodules require an explicit pinned-submodule transfer path"; exit 2; }

committed_config=$(mktemp /tmp/codex-release-config-XXXXXX)
chmod 600 "$committed_config"
git -C "$repo_path" show "${canonical_commit}:AppStore/release-config.json" > "$committed_config" 2>/dev/null || {
  print "FAIL  release config is absent from the exact commit"
  exit 2
}
jq empty "$committed_config" >/dev/null 2>&1 || { print "FAIL  committed release config is invalid JSON"; exit 2; }
[[ -r "$profile_path" ]] && jq empty "$profile_path" >/dev/null 2>&1 || { print "FAIL  private runner profile is missing or invalid"; exit 2; }

if [[ "$action" == archive && ( -z "$expected_version" || -z "$expected_build" ) ]]; then
  print "FAIL  archive mode requires --expected-version and --expected-build"
  exit 2
fi

asc_platform=$([[ "$platform" == iOS ]] && print IOS || print MAC_OS)
private_profile=$(jq -r '.profile // empty' "$profile_path")
repo_profile=$(jq -r '.stable_runner.profile // .stableRunner.profile // empty' "$committed_config")
ssh_host=$(jq -r '.sshHost // empty' "$profile_path")
workspace_root=$(jq -r '.workspaceRoot // empty' "$profile_path")
developer_dir=$(jq -r '.expected.developerDir // empty' "$profile_path")
expected_xcode_build=$(jq -r '.expected.xcodeBuild // empty' "$profile_path")
expected_macos_build=$(jq -r '.expected.macOSBuild // empty' "$profile_path")
private_sdk_version=$(jq -r --arg platform "$platform" 'if $platform == "iOS" then (.expected.iPhoneOSSDK // empty) else (.expected.macOSSDK // empty) end' "$profile_path")
signing_metadata_path=$(jq -r '.signingMetadataPath // empty' "$profile_path")

project=$(jq -r '.stable_runner.project // .stableRunner.project // empty' "$committed_config")
scheme=$(jq -r '.stable_runner.scheme // .stableRunner.scheme // empty' "$committed_config")
configuration=$(jq -r '.stable_runner.configuration // .stableRunner.configuration // "Release"' "$committed_config")
destination=$(jq -r --arg platform "$platform" '.stable_runner.destinations[$platform] // .stableRunner.destinations[$platform] // empty' "$committed_config")
expected_bundle=$(jq -r '.app.bundle_id // .app.bundleId // empty' "$committed_config")
app_id=$(jq -r '.app.id // empty' "$committed_config")
team_id=$(jq -r '.app.team_id // .app.teamId // empty' "$committed_config")
config_version=$(jq -r '.release.marketing_version // .release.marketingVersion // empty' "$committed_config")
config_build=$(jq -r '.release.source_build_number // .release.sourceBuildNumber // empty' "$committed_config")
repo_xcode_build=$(jq -r '.stable_runner.xcode_build // .stableRunner.xcodeBuild // empty' "$committed_config")
repo_macos_build=$(jq -r '.stable_runner.macos_build // .stable_runner.mac_os_build // .stableRunner.macOsBuild // empty' "$committed_config")
repo_sdk_version=$(jq -r --arg platform "$platform" '.stable_runner.sdk_versions[$platform] // .stableRunner.sdkVersions[$platform] // empty' "$committed_config")
minimum_os=$(jq -r --arg platform "$platform" '.stable_runner.minimum_os[$platform] // .stableRunner.minimumOs[$platform] // empty' "$committed_config")
architectures=$(jq -c --arg platform "$platform" '.stable_runner.architectures[$platform] // .stableRunner.architectures[$platform] // []' "$committed_config")
shipping_bundle_ids=$(jq -c '([.app.bundle_id // .app.bundleId] + (.stable_runner.shipping_bundle_ids // .stableRunner.shippingBundleIds // [])) | map(select(. != null and . != "")) | unique' "$committed_config")
signing_root=$(jq -c '.stable_runner.signing // .stableRunner.signing // {}' "$committed_config")
signing_mode=$(print -r -- "$signing_root" | jq -r '.mode // "automatic"')
signing_platform=$(print -r -- "$signing_root" | jq -c --arg platform "$platform" '.platforms[$platform] // .')
signing_certificate_id=
signing_profile_id=
signing_profile_name=
signing_profiles={}
installer_signing_certificate=$(print -r -- "$signing_platform" | jq -r '.installer_certificate_name // .installerCertificateName // empty')
warning_policy=$(jq -r '.stable_runner.warning_policy // .stableRunner.warningPolicy // "global"' "$committed_config")
export_manage_build=$(jq -r 'if (.stable_runner.export? | type) == "object" and (.stable_runner.export | has("manage_app_version_and_build_number")) then (.stable_runner.export.manage_app_version_and_build_number | tostring) elif (.stableRunner.export? | type) == "object" and (.stableRunner.export | has("manageAppVersionAndBuildNumber")) then (.stableRunner.export.manageAppVersionAndBuildNumber | tostring) else "" end' "$committed_config")
export_strip_symbols=$(jq -r 'if (.stable_runner.export? | type) == "object" and (.stable_runner.export | has("strip_swift_symbols")) then (.stable_runner.export.strip_swift_symbols | tostring) elif (.stableRunner.export? | type) == "object" and (.stableRunner.export | has("stripSwiftSymbols")) then (.stableRunner.export.stripSwiftSymbols | tostring) else "" end' "$committed_config")
export_upload_symbols=$(jq -r 'if (.stable_runner.export? | type) == "object" and (.stable_runner.export | has("upload_symbols")) then (.stable_runner.export.upload_symbols | tostring) elif (.stableRunner.export? | type) == "object" and (.stableRunner.export | has("uploadSymbols")) then (.stableRunner.export.uploadSymbols | tostring) else "" end' "$committed_config")
export_internal_testflight=$(jq -r 'if (.stable_runner.export? | type) == "object" and (.stable_runner.export | has("test_flight_internal_testing_only")) then (.stable_runner.export.test_flight_internal_testing_only | tostring) elif (.stableRunner.export? | type) == "object" and (.stableRunner.export | has("testFlightInternalTestingOnly")) then (.stableRunner.export.testFlightInternalTestingOnly | tostring) else "" end' "$committed_config")

[[ -n "$private_profile" && -n "$repo_profile" && "$repo_profile" == "$private_profile" ]] || { print "FAIL  repository runner profile does not match the configured private profile"; exit 1; }
[[ -n "$ssh_host" && -n "$developer_dir" && -n "$expected_xcode_build" && -n "$expected_macos_build" ]] || { print "FAIL  private runner profile is incomplete"; exit 1; }
[[ "$workspace_root" == /tmp/* && "$workspace_root" != /tmp && "$workspace_root" != */../* ]] || { print "FAIL  runner workspace root is unsafe"; exit 1; }
[[ -n "$project" && -n "$scheme" && -n "$destination" && -n "$expected_bundle" ]] || { print "FAIL  committed release config is missing project, scheme, destination, or bundle ID"; exit 1; }
[[ "$project" != /* && "$project" != *../* && "$project" == *.xcodeproj ]] || { print "FAIL  configured Xcode project path is unsafe"; exit 1; }
[[ "$warning_policy" == global || "$warning_policy" == project ]] || { print "FAIL  stable runner warning policy must be global or project"; exit 1; }
[[ "$signing_mode" == automatic || "$signing_mode" == manual ]] || { print "FAIL  stable runner signing mode must be automatic or manual"; exit 1; }

if (( upload == 1 )); then
  [[ "$app_id" =~ '^[0-9]+$' && "$team_id" =~ '^[A-Z0-9]{10}$' && "$expected_bundle" =~ '^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$' && "$expected_bundle" == *.* && "$expected_bundle" != *..* ]] || { print "FAIL  committed upload identity is incomplete"; exit 1; }
  [[ "$expected_version" =~ '^[0-9]+([.][0-9]+)+$' && "$expected_build" =~ '^[1-9][0-9]*$' ]] || { print "FAIL  committed version or build format is invalid"; exit 1; }
  [[ "$expected_version" == "$config_version" && "$expected_build" == "$config_build" ]] || { print "FAIL  CLI version/build does not match the exact committed release config"; exit 1; }
  [[ "$repo_xcode_build" == "$expected_xcode_build" && "$repo_macos_build" == "$expected_macos_build" && -n "$repo_sdk_version" && "$repo_sdk_version" == "$private_sdk_version" ]] || {
    print "FAIL  repository stable-runner toolchain does not match the private profile"
    exit 1
  }
  [[ -n "$minimum_os" ]] || { print "FAIL  committed minimum OS is missing"; exit 1; }
  print -r -- "$architectures" | jq -e 'type == "array" and length > 0 and all(.[]; type == "string" and length > 0)' >/dev/null || { print "FAIL  committed architecture list is invalid"; exit 1; }
  [[ "$export_manage_build" == false && "$export_strip_symbols" == true && "$export_upload_symbols" == true ]] || {
    print "FAIL  committed export policy must preserve the build number and include symbols"
    exit 1
  }
  if [[ "$asc_platform" == IOS ]]; then
    [[ "$export_internal_testflight" == true || "$export_internal_testflight" == false ]] || {
      print "FAIL  committed iOS export policy must declare testFlightInternalTestingOnly"
      exit 1
    }
  fi
  expected_confirmation="UPLOAD:${asc_platform}:${app_id}:${expected_bundle}:${expected_version}:${expected_build}:${canonical_commit}"
  [[ "$upload_confirmation" == "$expected_confirmation" ]] || { print "FAIL  upload confirmation does not match the exact committed candidate"; exit 2; }
elif [[ -n "$upload_confirmation" ]]; then
  print "FAIL  --confirm-upload is valid only with --upload"
  exit 2
fi

if [[ "$action" == validate-signing && "$signing_mode" != manual ]]; then
  print "FAIL  signing validation is available only for the manual distribution-signing contract"
  exit 1
fi
if [[ ( "$action" == archive || "$action" == validate-signing ) && "$signing_mode" == manual ]]; then
  [[ "$platform" == iOS && -n "$team_id" && -n "$signing_metadata_path" ]] || {
    print "FAIL  manual iOS archive signing requires a private metadata path and team"
    exit 1
  }
fi

"$script_dir/ssh_runner_preflight.sh" "$profile_path" || exit 1

repo_slug=$(basename "$repo_path" | tr -cd 'A-Za-z0-9._-')
[[ -n "$repo_slug" ]] || repo_slug=AppleApp
short_commit=${canonical_commit[1,12]}
quoted_root=${(q)workspace_root}

if ! git -C "$repo_path" cat-file -e "${canonical_commit}:$project" 2>/dev/null; then
  git -C "$repo_path" cat-file -e "${canonical_commit}:project.yml" 2>/dev/null || {
    print "FAIL  configured Xcode project and project.yml are both absent from the exact commit"
    exit 1
  }
  command -v xcodegen >/dev/null 2>&1 || {
    print "FAIL  generated Xcode project is absent from the commit and local xcodegen is unavailable"
    exit 1
  }
  generated_project_root=$(mktemp -d /tmp/codex-release-generated-XXXXXX)
  git -C "$repo_path" archive "$canonical_commit" | tar -xf - -C "$generated_project_root"
  (cd "$generated_project_root" && xcodegen generate)
  [[ -e "$generated_project_root/$project" ]] || { print "FAIL  exact-commit project generation failed"; exit 1; }
  print "PASS  generated the configured Xcode project from the exact commit"
fi

remote_dir=$(ssh -o LogLevel=QUIET "$ssh_host" "mkdir -p $quoted_root && mktemp -d $quoted_root/${repo_slug}-${short_commit}-XXXXXX")
[[ "$remote_dir" == "$workspace_root"/${repo_slug}-${short_commit}-* && "$remote_dir" != *'/../'* && "$remote_dir" != *'/..' && "$remote_dir" != *$'\n'* ]] || { print "FAIL  runner returned an unexpected task directory"; exit 1; }
remote_task_id=$(basename "$remote_dir")
print "INFO  allocated remote release task $remote_task_id"

if ! git -C "$repo_path" archive "$canonical_commit" | ssh -o LogLevel=QUIET "$ssh_host" "tar -xf - -C ${(q)remote_dir}"; then
  print "FAIL  exact-commit source transfer failed; retained task $remote_task_id"
  exit 1
fi
print "PASS  transferred exact commit $canonical_commit"

if [[ -n "$generated_project_root" ]]; then
  if ! tar -cf - -C "$generated_project_root" "$project" | ssh -o LogLevel=QUIET "$ssh_host" "tar -xf - -C ${(q)remote_dir}"; then
    print "FAIL  exact-commit generated project transfer failed; retained task $remote_task_id"
    exit 1
  fi
fi

waiter_hash=
if (( upload == 1 )); then
  waiter_hash=$(shasum -a 256 "$script_dir/wait_for_asc_build.rb" | awk '{print $1}')
  if ! tar -cf - -C "$script_dir" wait_for_asc_build.rb | ssh -o LogLevel=QUIET "$ssh_host" "mkdir -p ${(q)remote_dir}/.release-tools && tar -xf - -C ${(q)remote_dir}/.release-tools"; then
    print "FAIL  release waiter transfer failed; retained task $remote_task_id"
    exit 1
  fi
fi

remote_arguments=(
  "$remote_dir" "$workspace_root" "$developer_dir" "$project" "$scheme" "$configuration" "$destination"
  "$action" "$upload" "$expected_bundle" "$app_id" "$asc_platform" "$expected_version" "$expected_build"
  "$expected_xcode_build" "$expected_macos_build" "$repo_sdk_version" "$minimum_os" "$architectures"
  "$shipping_bundle_ids" "$team_id" "$signing_mode" "$signing_metadata_path" ""
  "" "" "$warning_policy" "{}" "$private_profile"
  "$canonical_commit" "$waiter_hash" "$export_manage_build" "$export_strip_symbols" "$export_upload_symbols"
  "$export_internal_testflight" "$platform" "$installer_signing_certificate"
)
quoted_arguments=()
for argument in "${remote_arguments[@]}"; do
  quoted_arguments+=("${(q)argument}")
done

ssh -o LogLevel=QUIET "$ssh_host" "/bin/zsh -s -- ${(j: :)quoted_arguments}" <<'REMOTE_SCRIPT'
set -eu
set -o pipefail
umask 077

task_dir=$1
workspace_root=$2
developer_dir=$3
project=$4
scheme=$5
configuration=$6
destination=$7
action=$8
upload=$9
expected_bundle=${10}
app_id=${11}
asc_platform=${12}
expected_version=${13}
expected_build=${14}
expected_xcode_build=${15}
expected_macos_build=${16}
expected_sdk_version=${17}
minimum_os=${18}
architectures=${19}
shipping_bundle_ids=${20}
team_id=${21}
signing_mode=${22}
signing_metadata_path=${23}
signing_certificate_id=${24}
signing_profile_id=${25}
signing_profile_name=${26}
warning_policy=${27}
signing_profiles=${28}
runner_profile=${29}
release_commit=${30}
waiter_hash=${31}
export_manage_build=${32}
export_strip_symbols=${33}
export_upload_symbols=${34}
export_internal_testflight=${35}
platform=${36}
installer_signing_certificate=${37}

[[ "$workspace_root" == /tmp/* && "$task_dir" == "$workspace_root"/* && "$task_dir" != *'/../'* && "$task_dir" != *'/..' && "$task_dir" != *$'\n'* ]] || { print "FAIL  remote task ownership check failed"; exit 1; }
export DEVELOPER_DIR="$developer_dir"
cd "$task_dir"

if [[ ! -e "$project" && -f project.yml ]]; then
  command -v xcodegen >/dev/null 2>&1 || { print "FAIL  xcodegen is unavailable on the runner"; exit 1; }
  xcodegen generate >/dev/null
fi
[[ -e "$project" ]] || { print "FAIL  configured Xcode project is absent after generation"; exit 1; }

if ! destination_report=$("$DEVELOPER_DIR/usr/bin/xcodebuild" -showdestinations -project "$project" -scheme "$scheme" 2>&1); then
  print "FAIL  Xcode could not resolve the configured destination"
  exit 1
fi
if [[ "$destination" == "generic/platform=iOS" ]] && print -r -- "$destination_report" | grep -Eq 'error:iOS .* is not installed'; then
  print "FAIL  the pinned runner is missing its configured iOS platform component"
  exit 1
fi
unset destination_report

if [[ "$action" == build ]]; then
  warning_arguments=()
  [[ "$warning_policy" == global ]] && warning_arguments+=(SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES)
  "$DEVELOPER_DIR/usr/bin/xcodebuild" -quiet clean build \
    -project "$project" -scheme "$scheme" -configuration "$configuration" -destination "$destination" \
    -derivedDataPath "$task_dir/DerivedData" CODE_SIGNING_ALLOWED=NO "${warning_arguments[@]}"
  exit 0
fi

release_lock="$workspace_root/.archive-upload.lock"
lock_owned=0
credential_dir=
keychain_path=
original_keychains=()
original_keychains_captured=0
if ! mkdir "$release_lock" 2>/dev/null; then
  print "FAIL  another archive or upload owns the stable runner"
  exit 1
fi
lock_owned=1
print -r -- "$release_commit" > "$release_lock/owner"

check_archive_resources() {
  available_kib=$(df -Pk "$workspace_root" 2>/dev/null | awk 'NR == 2 { print $4 }')
  [[ "$available_kib" =~ '^[0-9]+$' ]] && (( available_kib >= 15 * 1024 * 1024 )) || { print "FAIL  runner workspace has less than 15 GiB free"; return 1; }
  xcodebuild_count=$(pgrep -x xcodebuild 2>/dev/null | wc -l | tr -d '[:space:]')
  [[ "$xcodebuild_count" == 0 ]] || { print "FAIL  a competing xcodebuild process is active"; return 1; }
  xctest_count=$(pgrep -x xctest 2>/dev/null | wc -l | tr -d '[:space:]')
  [[ "$xctest_count" == 0 ]] || { print "FAIL  a competing xctest process is active"; return 1; }
  # Ignore the idle self-hosted Actions Runner.Listener; reject Fabricon task processes.
  fabricon_process_count=$(ps -axo comm | awk 'tolower($0) ~ /fabricon/ && $0 !~ /\/Runner\.Listener$/ { count++ } END { print count + 0 }')
  [[ "$fabricon_process_count" == 0 ]] || { print "FAIL  a Fabricon process is active on the stable runner"; return 1; }
}
check_archive_resources || exit 1

restore_keychain_context() {
  restore_status=0
  if (( original_keychains_captured == 1 )); then
    if security list-keychains -d user -s "${original_keychains[@]}" >/dev/null 2>&1; then
      restored_keychains=("${(@f)$(security list-keychains -d user | sed -E 's/^[[:space:]]*"//; s/"$//')}")
      if (( ${#restored_keychains} == ${#original_keychains} )); then
        for (( keychain_index = 1; keychain_index <= ${#original_keychains}; keychain_index++ )); do
          [[ "${restored_keychains[$keychain_index]}" == "${original_keychains[$keychain_index]}" ]] || restore_status=1
        done
      else
        restore_status=1
      fi
      (( restore_status == 0 )) && original_keychains_captured=0
    else
      restore_status=1
    fi
  fi
  if [[ -n "$keychain_path" ]]; then
    if security lock-keychain "$keychain_path" >/dev/null 2>&1; then
      keychain_path=
    else
      restore_status=1
    fi
  fi
  return "$restore_status"
}

unlock_existing_keychain() {
  RELEASE_KEYCHAIN_PATH="$keychain_path" RELEASE_KEYCHAIN_PASSWORD_FILE="$password_file" /usr/bin/expect <<'EXPECT'
set timeout 30
log_user 0
set channel [open $env(RELEASE_KEYCHAIN_PASSWORD_FILE) r]
set password [string trimright [read $channel] "\r\n"]
close $channel
if {$password eq ""} { exit 1 }
spawn -noecho /usr/bin/security unlock-keychain $env(RELEASE_KEYCHAIN_PATH)
expect {
  -nocase -re {password[^:]*:\s*$} { send -- "$password\r"; exp_continue }
  eof {}
  timeout { set password ""; exit 1 }
}
set result [wait]
set password ""
exit [lindex $result 3]
EXPECT
}

cleanup_remote() {
  exit_status=$?
  cleanup_failed=0
  trap - EXIT HUP INT TERM
  if [[ -n "$credential_dir" && "$credential_dir" == "$task_dir"/.credentials-* ]]; then
    rm -rf -- "$credential_dir" || cleanup_failed=1
  fi
  if (( original_keychains_captured == 1 )) || [[ -n "$keychain_path" ]]; then
    if ! restore_keychain_context; then
      restore_keychain_context || cleanup_failed=1
    fi
  fi
  if (( lock_owned == 1 )) && [[ "$release_lock" == "$workspace_root/.archive-upload.lock" ]]; then
    rm -f -- "$release_lock/owner" || cleanup_failed=1
    rmdir "$release_lock" >/dev/null 2>&1 || cleanup_failed=1
  fi
  if (( cleanup_failed != 0 )); then
    print "FAIL  sensitive runner cleanup did not complete" >&2
    (( exit_status != 0 )) || exit_status=1
  fi
  exit "$exit_status"
}
trap cleanup_remote EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

credentials_file="$HOME/.codex/secrets/app-store-connect.env"
credential_dir=$(mktemp -d "$task_dir/.credentials-XXXXXX")
chmod 700 "$credential_dir"
needs_asc_credentials=0
if (( upload == 1 )) || [[ "$signing_mode" == automatic && "$action" == archive ]]; then
  needs_asc_credentials=1
fi
if (( needs_asc_credentials == 1 )); then
  [[ -r "$credentials_file" && "$(stat -f '%Lp' "$credentials_file" 2>/dev/null)" == 600 ]] || { print "FAIL  remote App Store Connect credential file is unavailable"; exit 1; }
  set -a
  source "$credentials_file"
  set +a
  for variable in ASC_KEY_PATH ASC_KEY_ID ASC_ISSUER_ID; do
    [[ -n "${(P)variable:-}" ]] || { print "FAIL  remote App Store Connect credentials are incomplete"; exit 1; }
  done
  [[ "$ASC_KEY_ID" =~ '^[A-Za-z0-9]+$' && "$ASC_ISSUER_ID" =~ '^[A-Za-z0-9-]+$' ]] || { print "FAIL  remote App Store Connect credential identifiers are malformed"; exit 1; }
  [[ -f "$ASC_KEY_PATH" && ! -L "$ASC_KEY_PATH" && "$(stat -f '%Lp' "$ASC_KEY_PATH" 2>/dev/null)" == 600 && "$(stat -f '%u' "$ASC_KEY_PATH" 2>/dev/null)" == "$(id -u)" ]] || {
    print "FAIL  remote App Store Connect private key invariant failed"
    exit 1
  }
  temporary_key="$credential_dir/AuthKey_${ASC_KEY_ID}.p8"
  install -m 600 "$ASC_KEY_PATH" "$temporary_key"
  export ASC_KEY_PATH="$temporary_key"
  export API_PRIVATE_KEYS_DIR="$credential_dir"
fi

sanitize_output() {
  raw_path=$1
  safe_path=$2
  if ! REDACTION_VALUES_FILE="$redaction_values" ruby -e '
    text = File.binread(ARGV.fetch(0))
    %w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH API_PRIVATE_KEYS_DIR].each do |name|
      value = ENV[name]
      text = text.gsub(value, "[REDACTED]") if value && !value.empty?
    end
    if (path = ENV["REDACTION_VALUES_FILE"]) && File.file?(path)
      File.readlines(path, chomp: true).reject(&:empty?).each { |value| text = text.gsub(value, "[REDACTED]") }
    end
    File.binwrite(ARGV.fetch(1), text)
  ' "$raw_path" "$safe_path"; then
    rm -f -- "$raw_path" "$safe_path"
    print "FAIL  release output could not be sanitized" >&2
    return 1
  fi
  rm -f -- "$raw_path"
}

run_sensitive() {
  log_name=$1
  shift
  raw_log="$task_dir/.${log_name}.raw"
  safe_log="$task_dir/${log_name}.log"
  set +e
  "$@" >"$raw_log" 2>&1
  command_status=$?
  set -e
  sanitize_output "$raw_log" "$safe_log"
  if (( command_status != 0 )); then
    tail -n 80 "$safe_log" >&2 || true
    return "$command_status"
  fi
  rm -f -- "$safe_log"
}

archive_path="$task_dir/release.xcarchive"
archive_arguments=(
  -quiet clean archive -project "$project" -scheme "$scheme" -configuration "$configuration"
  -destination "$destination" -archivePath "$archive_path" -derivedDataPath "$task_dir/DerivedData"
  MARKETING_VERSION="$expected_version" CURRENT_PROJECT_VERSION="$expected_build"
)
[[ "$warning_policy" == global ]] && archive_arguments+=(SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES)

profile_count=0
keychain_path=
redaction_values="$credential_dir/signing-redactions"
if [[ "$signing_mode" == manual ]]; then
  [[ "$platform" == iOS && "$signing_metadata_path" != /* && "$signing_metadata_path" != *../* ]] || { print "FAIL  private iOS signing metadata path is invalid"; exit 1; }
  signing_metadata="$HOME/$signing_metadata_path"
  [[ -f "$signing_metadata" && ! -L "$signing_metadata" && -r "$signing_metadata" && "$(stat -f '%Lp' "$signing_metadata" 2>/dev/null)" == 600 ]] || { print "FAIL  private signing metadata is unavailable"; exit 1; }
  private_signing=$(jq -c --arg platform "$platform" '.platforms[$platform] // .' "$signing_metadata")
  signing_certificate_id=$(print -r -- "$private_signing" | jq -r '.certificateId // empty')
  certificate_type=$(print -r -- "$private_signing" | jq -r '.certificateType // empty')
  certificate_expiration=$(print -r -- "$private_signing" | jq -r '.certificateExpirationDate // empty')
  [[ -n "$signing_certificate_id" && "$certificate_type" == DISTRIBUTION && -n "$certificate_expiration" ]] || { print "FAIL  existing private distribution-signing metadata is incomplete"; exit 1; }
  signing_profiles=$(print -r -- "$private_signing" | jq -c '.profiles // {}')
  shipping_count=$(print -r -- "$shipping_bundle_ids" | jq 'length')
  [[ "$shipping_count" == 1 && "$(print -r -- "$shipping_bundle_ids" | jq -r '.[0]')" == "$expected_bundle" ]] || { print "FAIL  manual signing supports only the declared single-app shipping bundle set"; exit 1; }
  profile_count=$(print -r -- "$signing_profiles" | jq 'length')
  [[ "$(print -r -- "$signing_profiles" | jq -r --arg bundle "$expected_bundle" 'has($bundle)')" == true ]] || { print "FAIL  private App Store profile is missing for the shipping bundle"; exit 1; }
  selected_profile=$(print -r -- "$signing_profiles" | jq -c --arg bundle "$expected_bundle" '.[$bundle]')
  signing_profile_id=$(print -r -- "$selected_profile" | jq -r '.profileId // empty')
  signing_profile_name=$(print -r -- "$selected_profile" | jq -r '.profileName // empty')
  signing_profile_uuid=$(print -r -- "$selected_profile" | jq -r '.profileUuid // empty')
  profile_type=$(print -r -- "$selected_profile" | jq -r '.profileType // empty')
  profile_state=$(print -r -- "$selected_profile" | jq -r '.profileState // empty')
  profile_expiration=$(print -r -- "$selected_profile" | jq -r '.profileExpirationDate // empty')
  [[ -n "$signing_profile_id" && -n "$signing_profile_name" && "$signing_profile_uuid" =~ '^[0-9a-fA-F-]{36}$' && "$profile_type" == IOS_APP_STORE && "$profile_state" == ACTIVE && -n "$profile_expiration" ]] || { print "FAIL  selected private profile is not an active App Store profile"; exit 1; }
  python3 -c 'import datetime,sys; values=[datetime.datetime.fromisoformat(x.replace("Z","+00:00")) for x in sys.argv[1:]]; now=datetime.datetime.now(datetime.timezone.utc); sys.exit(0 if all(x > now for x in values) else 1)' "$profile_expiration" "$certificate_expiration" || { print "FAIL  private signing profile or certificate is expired"; exit 1; }
  signing_profiles=$(jq -cn --arg bundle "$expected_bundle" --arg id "$signing_profile_id" --arg name "$signing_profile_name" --arg uuid "$signing_profile_uuid" '{($bundle):{profile_id:$id,profile_name:$name,profile_uuid:$uuid}}')
  profile_count=$(print -r -- "$signing_profiles" | jq 'length')
  profile_path="$HOME/Library/MobileDevice/Provisioning Profiles/$signing_profile_uuid.mobileprovision"
  [[ -r "$profile_path" && -f "$profile_path" && ! -L "$profile_path" ]] || { print "FAIL  selected App Store profile is not installed"; exit 1; }
  profile_verifier="$task_dir/scripts/stable-runner/verify_ios_profile.py"
  [[ -r "$profile_verifier" ]] || { print "FAIL  versioned App Store profile verifier is missing"; exit 1; }
  decoded_profile="$credential_dir/selected-profile.plist"
  security cms -D -i "$profile_path" >"$decoded_profile" 2>/dev/null || { print "FAIL  selected App Store profile could not be decoded"; exit 1; }
  certificate_hashes=$(python3 "$profile_verifier" --profile "$decoded_profile" --bundle-id "$expected_bundle" --team-id "$team_id" --profile-uuid "$signing_profile_uuid" --profile-name "$signing_profile_name" --print-certificate-sha1s) || { print "FAIL  selected App Store profile failed bundle, team, distribution, or expiry verification"; exit 1; }
  keychain_path=$(print -r -- "$signing_metadata" | jq -r '.keychainPath // empty')
  password_file=$(print -r -- "$signing_metadata" | jq -r '.passwordFile // empty')
  [[ "$keychain_path" == "$HOME"/Library/Keychains/* && -f "$keychain_path" && ! -L "$keychain_path" && -r "$password_file" && -f "$password_file" && ! -L "$password_file" && "$(stat -f '%Lp' "$password_file" 2>/dev/null)" == 600 && "$(stat -f '%u' "$password_file" 2>/dev/null)" == "$(id -u)" ]] || { print "FAIL  existing release keychain or password metadata is unavailable"; exit 1; }
  identity_report=$(security find-identity -v -p codesigning "$keychain_path" 2>/dev/null) || { print "FAIL  existing distribution identity could not be inspected"; exit 1; }
  identity_count=$(print -r -- "$identity_report" | awk '/valid identities found/ {print $1}')
  signing_certificate_hash=$(print -r -- "$identity_report" | awk '/Apple Distribution:/ {print toupper($2)}')
  [[ "$identity_count" == 1 && "$signing_certificate_hash" =~ '^[A-F0-9]{40}$' ]] || { print "FAIL  existing keychain must contain exactly one valid distribution identity"; exit 1; }
  print -r -- "$identity_report" | grep -F "($team_id)" >/dev/null || { print "FAIL  distribution identity team does not match"; exit 1; }
  print -r -- "$certificate_hashes" | jq -e --arg sha1 "$signing_certificate_hash" 'index($sha1) != null' >/dev/null || { print "FAIL  selected profile does not authorize the existing distribution identity"; exit 1; }
  original_keychains=("${(@f)$(security list-keychains -d user | sed -E 's/^[[:space:]]*"//; s/"$//')}")
  (( ${#original_keychains} > 0 )) || { print "FAIL  existing user keychain search list is empty"; exit 1; }
  original_keychains_captured=1
  if [[ "$action" == validate-signing ]]; then
    [[ -x /usr/bin/expect ]] || { print "FAIL  secure existing-keychain unlock prompt handler is unavailable"; exit 1; }
    unlock_existing_keychain || { print "FAIL  existing release keychain could not be unlocked without changing its ACL"; exit 1; }
    extraction_smoke_dir="$credential_dir/codesign-key-smoke"
    mkdir -m 700 "$extraction_smoke_dir"
    cp /usr/bin/true "$extraction_smoke_dir/signed-true" || { print "FAIL  temporary signing smoke input could not be prepared"; exit 1; }
    if ! codesign --force --timestamp=none --sign "$signing_certificate_hash" --keychain "$keychain_path" "$extraction_smoke_dir/signed-true" >/dev/null 2>&1 ||
      ! codesign --verify --strict "$extraction_smoke_dir/signed-true" >/dev/null 2>&1 ||
      ! (cd "$extraction_smoke_dir" && codesign --display --extract-certificates "$extraction_smoke_dir/signed-true" >/dev/null 2>&1) ||
      [[ ! -s "$extraction_smoke_dir/codesign0" ]]; then
      print "FAIL  existing identity could not sign and verify a temporary smoke artifact without ACL changes"
      exit 1
    fi
    smoke_signer_hash=$(shasum -a 1 "$extraction_smoke_dir/codesign0" | awk '{print toupper($1)}')
    [[ "$smoke_signer_hash" == "$signing_certificate_hash" ]] || { print "FAIL  temporary signing smoke artifact used a different distribution identity"; exit 1; }
    restore_keychain_context || { print "FAIL  original runner keychain context could not be restored after signing validation"; exit 1; }
    print "PASS  private App Store profile and existing signer can sign, verify, and extract certificates without ACL changes"
    exit 0
  fi
  : >"$redaction_values"
  chmod 600 "$redaction_values"
  for private_value in "$signing_certificate_id" "$signing_profile_id" "$signing_profile_name" "$signing_profile_uuid" "$signing_certificate_hash" "$keychain_path" "$profile_path" "$password_file"; do
    [[ -n "$private_value" ]] && print -r -- "$private_value" >>"$redaction_values"
  done
  if (( needs_asc_credentials == 1 )); then
    for private_value in "$ASC_KEY_ID" "$ASC_ISSUER_ID" "$ASC_KEY_PATH"; do
      [[ -n "$private_value" ]] && print -r -- "$private_value" >>"$redaction_values"
    done
  fi
  original_keychains=("${(@f)$(security list-keychains -d user | sed -E 's/^[[:space:]]*"//; s/"$//')}")
  (( ${#original_keychains} > 0 )) || { print "FAIL  existing user keychain search list is empty"; exit 1; }
  original_keychains_captured=1
  [[ -x /usr/bin/expect ]] || { print "FAIL  secure existing-keychain unlock prompt handler is unavailable"; exit 1; }
  unlock_existing_keychain || { print "FAIL  existing release keychain could not be unlocked without changing its ACL"; exit 1; }
  security list-keychains -d user -s "$keychain_path" >/dev/null || { print "FAIL  release keychain search-list selection failed"; exit 1; }
  manual_signing_arguments=(CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$team_id" CODE_SIGN_IDENTITY="$signing_certificate_hash" OTHER_CODE_SIGN_FLAGS="--keychain $keychain_path" PROVISIONING_PROFILE_SPECIFIER="$signing_profile_name")
  run_sensitive archive "$DEVELOPER_DIR/usr/bin/xcodebuild" "${archive_arguments[@]}" "${manual_signing_arguments[@]}" || { print "FAIL  signed archive failed"; exit 1; }
else
  run_sensitive archive "$DEVELOPER_DIR/usr/bin/xcodebuild" "${archive_arguments[@]}" \
    -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" || {
    print "FAIL  signed archive failed"
    exit 1
  }
fi

verify_manual_ios_component() {
  component_path=$1
  component_bundle=$2
  signed_object=$3
  [[ "$asc_platform" == IOS && "$signing_mode" == manual ]] || return 0
  selected_profile=$(print -r -- "$signing_profiles" | jq -c --arg bundle "$component_bundle" '.[$bundle] // empty')
  [[ -n "$selected_profile" ]] || { print "FAIL  no selected App Store profile for an archived shipping bundle"; return 1; }
  component_profile_uuid=$(print -r -- "$selected_profile" | jq -r '.profile_uuid')
  component_profile_name=$(print -r -- "$selected_profile" | jq -r '.profile_name')
  embedded_profile="$component_path/embedded.mobileprovision"
  [[ -r "$embedded_profile" && -f "$embedded_profile" ]] || { print "FAIL  signed shipping bundle has no embedded provisioning profile"; return 1; }
  decoded_component_profile="$credential_dir/decoded-component-profile.plist"
  security cms -D -i "$embedded_profile" >"$decoded_component_profile" 2>/dev/null || { print "FAIL  embedded provisioning profile could not be decoded"; return 1; }
  python3 "$profile_verifier" --profile "$decoded_component_profile" --bundle-id "$component_bundle" --team-id "$team_id" --profile-uuid "$component_profile_uuid" --profile-name "$component_profile_name" --certificate-sha1 "$signing_certificate_hash" >/dev/null || { print "FAIL  embedded provisioning profile does not match the selected App Store identity"; return 1; }
  signature_dir=$(mktemp -d "$credential_dir/codesign-certificates-XXXXXX") || { print "FAIL  temporary signature inspection directory could not be created"; return 1; }
  (cd "$signature_dir" && codesign --display --extract-certificates "$signed_object" >/dev/null 2>&1) || {
    rm -rf -- "$signature_dir"
    print "FAIL  code-signing certificate could not be extracted"
    return 1
  }
  [[ -s "$signature_dir/codesign0" ]] || { rm -rf -- "$signature_dir"; print "FAIL  code-signing leaf certificate is missing"; return 1; }
  observed_signer_sha1=$(shasum -a 1 "$signature_dir/codesign0" | awk '{print toupper($1)}')
  rm -rf -- "$signature_dir"
  [[ "$observed_signer_sha1" == "$signing_certificate_hash" ]] || { print "FAIL  archived signer identity differs from the selected distribution identity"; return 1; }
  rm -f -- "$decoded_component_profile"
}

apps=("$archive_path"/Products/Applications/*.app(N))
(( ${#apps} == 1 )) || { print "FAIL  expected exactly one archived app"; exit 1; }
app_path=${apps[1]}
if [[ "$asc_platform" == IOS ]]; then
  app_plist="$app_path/Info.plist"
  minimum_key=MinimumOSVersion
else
  app_plist="$app_path/Contents/Info.plist"
  minimum_key=LSMinimumSystemVersion
fi
actual_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_plist")
actual_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_plist")
actual_build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_plist")
actual_xcode=$(/usr/libexec/PlistBuddy -c 'Print :DTXcodeBuild' "$app_plist")
actual_macos=$(/usr/libexec/PlistBuddy -c 'Print :BuildMachineOSBuild' "$app_plist")
actual_sdk=$(/usr/libexec/PlistBuddy -c 'Print :DTSDKName' "$app_plist")
[[ "$actual_bundle" == "$expected_bundle" && "$actual_version" == "$expected_version" && "$actual_build" == "$expected_build" ]] || { print "FAIL  archived app identity mismatch"; exit 1; }
[[ "$actual_xcode" == "$expected_xcode_build" && "$actual_macos" == "$expected_macos_build" ]] || { print "FAIL  archived toolchain identity mismatch"; exit 1; }
if [[ -n "$expected_sdk_version" ]]; then
  expected_sdk_name=$([[ "$asc_platform" == IOS ]] && print "iphoneos${expected_sdk_version}" || print "macosx${expected_sdk_version}")
  [[ "$actual_sdk" == "$expected_sdk_name" ]] || { print "FAIL  archived SDK identity mismatch"; exit 1; }
fi
if [[ -n "$minimum_os" ]]; then
  [[ "$(/usr/libexec/PlistBuddy -c "Print :$minimum_key" "$app_plist")" == "$minimum_os" ]] || { print "FAIL  archived minimum OS mismatch"; exit 1; }
fi

executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app_plist")
binary_path=$([[ "$asc_platform" == IOS ]] && print "$app_path/$executable" || print "$app_path/Contents/MacOS/$executable")
architecture_list=("${(@f)$(print -r -- "$architectures" | jq -r '.[]')}")
(( ${#architecture_list} == 0 )) || lipo "$binary_path" -verify_arch "${architecture_list[@]}" >/dev/null || { print "FAIL  archived executable architecture mismatch"; exit 1; }

shipping_paths=("$app_path" "$app_path"/PlugIns/*.appex(N))
actual_bundle_ids=()
for shipping_path in "${shipping_paths[@]}"; do
  codesign --verify --deep --strict "$shipping_path" >/dev/null 2>&1 || { print "FAIL  archived code signature verification failed"; exit 1; }
  if [[ "$asc_platform" == IOS ]]; then
    shipping_plist="$shipping_path/Info.plist"
  else
    shipping_plist="$shipping_path/Contents/Info.plist"
  fi
  shipping_bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$shipping_plist")
  actual_bundle_ids+=("$shipping_bundle")
  entitlements="$task_dir/.entitlements.plist"
  if [[ "$asc_platform" == IOS ]]; then
    signed_object="$shipping_path"
    application_identifier_key=application-identifier
  else
    shipping_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$shipping_plist")
    signed_object="$shipping_path/Contents/MacOS/$shipping_executable"
    application_identifier_key=com.apple.application-identifier
  fi
  codesign -d --entitlements :- "$signed_object" >"$entitlements" 2>/dev/null || { print "FAIL  archived signing entitlements are unavailable"; exit 1; }
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.team-identifier' "$entitlements")" == "$team_id" ]] || { print "FAIL  archived team identity mismatch"; exit 1; }
  [[ "$(/usr/libexec/PlistBuddy -c "Print :$application_identifier_key" "$entitlements")" == "$team_id.$shipping_bundle" ]] || { print "FAIL  archived application identifier mismatch"; exit 1; }
  verify_manual_ios_component "$shipping_path" "$shipping_bundle" "$signed_object" || exit 1
  rm -f -- "$entitlements"
done
actual_sorted=$(printf '%s\n' "${actual_bundle_ids[@]}" | sort -u | jq -Rsc 'split("\n") | map(select(length > 0))')
expected_sorted=$(print -r -- "$shipping_bundle_ids" | jq -c 'sort | unique')
[[ "$actual_sorted" == "$expected_sorted" ]] || { print "FAIL  archived shipping bundle set mismatch"; exit 1; }
archive_sha256=$(python3 - "$archive_path" <<'PYHASH'
import hashlib, os, sys
root = sys.argv[1]
digest = hashlib.sha256()
for base, dirs, files in os.walk(root, followlinks=False):
    dirs.sort()
    files.sort()
    for name in dirs + files:
        path = os.path.join(base, name)
        relative = os.path.relpath(path, root).encode()
        digest.update(relative + b"\0")
        if os.path.islink(path):
            digest.update(b"link\\0" + os.readlink(path).encode())
        elif os.path.isfile(path):
            with open(path, "rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
print(digest.hexdigest())
PYHASH
)
[[ "$archive_sha256" =~ '^[a-f0-9]{64}$' ]] || { print "FAIL  archive content hash could not be computed"; exit 1; }
print "PASS  archive identity, manual signer/profile, platform, and toolchain assertions passed"

if (( upload == 0 )); then
  print "PASS  remote archive completed; archive retained"
  exit 0
fi

waiter="$task_dir/.release-tools/wait_for_asc_build.rb"
[[ -r "$waiter" && "$(shasum -a 256 "$waiter" | awk '{print $1}')" == "$waiter_hash" ]] || { print "FAIL  exact-build waiter integrity check failed"; exit 1; }
ruby "$waiter" --app-id "$app_id" --platform "$asc_platform" --version "$expected_version" --build "$expected_build" --expect-absent --json >/dev/null || {
  print "FAIL  exact build number is not available for upload"
  exit 1
}

export_options="$task_dir/ExportOptions.plist"
plutil -create xml1 "$export_options"
plutil -insert method -string app-store-connect "$export_options"
plutil -insert destination -string export "$export_options"
plutil -insert signingStyle -string "$signing_mode" "$export_options"
plutil -insert teamID -string "$team_id" "$export_options"
plutil -insert manageAppVersionAndBuildNumber -bool "$export_manage_build" "$export_options"
plutil -insert stripSwiftSymbols -bool "$export_strip_symbols" "$export_options"
plutil -insert uploadSymbols -bool "$export_upload_symbols" "$export_options"
if [[ "$asc_platform" == IOS ]]; then
  plutil -insert testFlightInternalTestingOnly -bool "$export_internal_testflight" "$export_options"
  [[ "$signing_mode" != manual ]] || plutil -insert signingCertificate -string "$signing_certificate_hash" "$export_options"
else
  plutil -insert signingCertificate -string 'Apple Distribution' "$export_options"
  installer_selector=${installer_signing_certificate:-Mac Installer Distribution}
  plutil -insert installerSigningCertificate -string "$installer_selector" "$export_options"
fi
if [[ "$signing_mode" == manual ]]; then
  if (( profile_count > 0 )); then
    export_profiles=$(print -r -- "$signing_profiles" | jq -c 'with_entries(.value = (.value.profile_name // .value.profileName))')
  else
    export_profiles=$(jq -cn --arg bundle "$expected_bundle" --arg profile "$signing_profile_name" '{($bundle):$profile}')
  fi
  plutil -insert provisioningProfiles -json "$export_profiles" "$export_options"
fi

export_path="$task_dir/export"
export_arguments=(-exportArchive -archivePath "$archive_path" -exportPath "$export_path" -exportOptionsPlist "$export_options")
if [[ "$signing_mode" == automatic ]]; then
  export_arguments+=(-allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
run_sensitive export "$DEVELOPER_DIR/usr/bin/xcodebuild" "${export_arguments[@]}" || { print "FAIL  deterministic App Store export failed"; exit 1; }

if [[ "$asc_platform" == IOS ]]; then
  packages=("$export_path"/*.ipa(N))
  upload_type=ios
else
  packages=("$export_path"/*.pkg(N))
  upload_type=macos
fi
(( ${#packages} == 1 )) || { print "FAIL  expected exactly one exported upload package"; exit 1; }
package_path=${packages[1]}
package_sha256=$(shasum -a 256 "$package_path" | awk '{print $1}')
if [[ "$asc_platform" == IOS && "$signing_mode" == manual ]]; then
  ipa_inspection="$task_dir/.ipa-inspection"
  mkdir -m 700 "$ipa_inspection"
  unzip -qq "$package_path" -d "$ipa_inspection" || { print "FAIL  exported IPA could not be inspected"; exit 1; }
  exported_app_path=$(find "$ipa_inspection/Payload" -maxdepth 1 -type d -name "*.app" -print -quit)
  [[ -n "$exported_app_path" && -d "$exported_app_path" ]] || { print "FAIL  exported IPA does not contain exactly one app"; exit 1; }
  exported_app_plist="$exported_app_path/Info.plist"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$exported_app_plist")" == "$expected_bundle" && "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$exported_app_plist")" == "$expected_version" && "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$exported_app_plist")" == "$expected_build" ]] || { print "FAIL  exported IPA app identity mismatch"; exit 1; }
  codesign --verify --deep --strict "$exported_app_path" >/dev/null 2>&1 || { print "FAIL  exported IPA code signature verification failed"; exit 1; }
  exported_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$exported_app_plist")
  verify_manual_ios_component "$exported_app_path" "$expected_bundle" "$exported_app_path/$exported_executable" || exit 1
  exported_entitlements="$task_dir/.exported-entitlements.plist"
  codesign -d --entitlements :- "$exported_app_path" >"$exported_entitlements" 2>/dev/null || { print "FAIL  exported IPA entitlements are unavailable"; exit 1; }
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.team-identifier' "$exported_entitlements")" == "$team_id" && "$(/usr/libexec/PlistBuddy -c 'Print :application-identifier' "$exported_entitlements")" == "$team_id.$expected_bundle" ]] || { print "FAIL  exported IPA team or application entitlement mismatch"; exit 1; }
  rm -f -- "$exported_entitlements" "$export_options"
  rm -rf -- "$ipa_inspection"
  restore_keychain_context || { print "FAIL  original runner keychain context could not be restored"; exit 1; }
fi

run_sensitive upload xcrun altool --upload-app --file "$package_path" --type "$upload_type" --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" || {
  print "FAIL  App Store Connect upload transport failed"
  exit 1
}
print "PASS  upload transport accepted the exact package"

valid_json=$(ruby "$waiter" --app-id "$app_id" --platform "$asc_platform" --version "$expected_version" --build "$expected_build" --json) || {
  print "FAIL  uploaded build did not reach VALID; release task retained"
  exit 1
}
[[ "$(print -r -- "$valid_json" | jq -r '.state')" == VALID ]] || { print "FAIL  uploaded build did not reach VALID"; exit 1; }
asc_build_id=$(print -r -- "$valid_json" | jq -r '.build_id')
signing_verification=XCODE_CODE_SIGNATURE_VERIFIED
[[ "$signing_mode" != manual ]] || signing_verification=MANUAL_IOS_PROFILE_AND_SIGNER_VERIFIED
receipt=$(jq -cn \
  --arg signing_verification "$signing_verification" \
  --arg app_id "$app_id" --arg platform "$asc_platform" --arg bundle_id "$expected_bundle" \
  --arg marketing_version "$expected_version" --arg build "$expected_build" --arg commit "$release_commit" \
  --arg runner_profile "$runner_profile" --arg xcode_build "$expected_xcode_build" --arg macos_build "$expected_macos_build" \
  --arg sdk_version "$expected_sdk_version" --arg archive_sha256 "$archive_sha256" --arg package_sha256 "$package_sha256" --arg asc_build_id "$asc_build_id" \
  --argjson testflight_internal_only "${export_internal_testflight:-false}" \
  '{schema_version:1,state:"VALID",app_id:$app_id,platform:$platform,bundle_id:$bundle_id,marketing_version:$marketing_version,build:$build,commit:$commit,runner_profile:$runner_profile,xcode_build:$xcode_build,macos_build:$macos_build,sdk_version:$sdk_version,archive_sha256:$archive_sha256,package_sha256:$package_sha256,signing_verification:$signing_verification,asc_build_id:$asc_build_id,testflight_internal_only:$testflight_internal_only}')
print "RELEASE_RECEIPT $receipt"
REMOTE_SCRIPT
remote_status=$?

if (( remote_status != 0 )); then
  print "FAIL  remote release action failed; retained task $remote_task_id"
  exit "$remote_status"
fi

if [[ "$action" == archive && "$upload" == 0 ]]; then
  print "PASS  remote archive completed; retained task $remote_task_id"
  exit 0
fi
if (( keep_remote == 1 )); then
  print "PASS  remote action completed; retained task $remote_task_id"
  exit 0
fi

if [[ "$remote_dir" == "$workspace_root"/${repo_slug}-${short_commit}-* ]]; then
  if ssh -o LogLevel=QUIET "$ssh_host" "rm -rf -- ${(q)remote_dir}"; then
    print "PASS  remote action completed and its task-owned resources were cleaned"
  else
    print "FAIL  remote action completed but task-owned cleanup failed"
    exit 1
  fi
else
  print "FAIL  refusing to clean an unexpected remote task path"
  exit 1
fi
