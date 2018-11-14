#!/bin/bash
set -euo pipefail

readonly \
    BEGINNING_PATTERN='#-----------Docker-Hoster-Domains----------#' \
    ENDING_PATTERN='#-----Do-not-add-hosts-after-this-line-----#' \
    FILE="${FILE:-/tmp/hosts}"\
    SOCKET="${SOCKET:-/tmp/docker.sock}"

declare -A hostLines=()

_log () {
    local format="$1"
    shift
    printf "[%s] $format\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$@" >&2
}

_handle() {
    _log 'Removing all containers from "%s"' "$FILE"
    _removeFromHosts
    exit 0
}

_query() {
    local endpoint="$1"
    shift
    curl -G -X GET --silent \
        --unix-socket "$SOCKET" "$@" \
        "http://localhost/$endpoint"
}

_containers() {
    _query containers/json \
        --fail --data-urlencode \
            'filters={"status":["running"]}'
}

_containerIds() {
    _containers | jq -r .[].Id
}

_events() {
    _query events \
        --fail --data-urlencode \
            'filters={"event":["die","kill","pause","restart","start","stop","unpause"],"type":["container"]}'
}

_inspect() {
    _query "containers/$1/json"
}

_buildHostLine() {
    jq -r '(.Name | sub("^/";"")) as $name
        | .NetworkSettings.Networks
        | ..
        | select(.IPAddress? != null and .IPAddress? != "")
        | "\(.IPAddress)\t\($name) \(try (.Aliases | join(" ")) catch "")"'
}

_sanitizeRegex() {
    sed 's:[\/&]:\\&:g;$!s/$/\\/'
}

_buildLines() {
    local ids="${1:-$(_containerIds)}"
    for id in $ids; do
        inspect="$(_inspect "$id")"
        if jq -e .State.Running <<< "$inspect" >/dev/null; then
            hostLines["_$id"]="$(_buildHostLine <<< "$inspect")"
        else
            unset hostLines["_$id"]
        fi
    done
    _saveToHosts
}

_removeFromHosts() {
    local contents
    contents="$(<"${FILE}")"
    sed -n "/$(_sanitizeRegex <<< "$BEGINNING_PATTERN")/q;p" <<< "$contents" | sed '${/^$/d;}' > "$FILE"
}

_saveToHosts() {
    local lines
    lines="$(printf '%s\n' "${hostLines[@]}" | grep .)"
    _removeFromHosts
    printf "\n%s\n%s\n%s\n" "$BEGINNING_PATTERN" "$lines" "$ENDING_PATTERN" >> "$FILE"
}

_main() {
    trap '_handle' SIGINT SIGTERM

    _log 'Adding all containers to "%s"' "$FILE"
    _buildLines
    while true; do
        while read -r event; do
            _log 'Change triggered due to %s' \
                "$(jq -r '"\(.Action) event on \"\(.Actor.Attributes.name)\""' <<< "$event")"
            sleep 1
            _buildLines "$(jq -r .id <<< "$event")"
        done < <(_events)
    done
}

if [[ "$0" = "$BASH_SOURCE" ]]; then
    _main "$@"
fi
