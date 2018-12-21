#!/bin/bash

readonly \
    BEGINNING_PATTERN='#-----------Docker-Hoster-Domains----------#' \
    ENDING_PATTERN='#-----Do-not-add-hosts-after-this-line-----#' \
    FILE="${FILE:-/tmp/hosts}"\
    SOCKET="${SOCKET:-/tmp/docker.sock}"

export DOCKER_HOST="unix://$SOCKET"

declare -A hostLines=()

_log () {
    local format="$1"
    shift
    printf "[%s] $format\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$@" >&2
}

_handle() {
    _log 'Removing all containers from "%s"' "$FILE"
    _defaultHosts -w
    exit 0
}

_containerIds() {
    docker ps \
        --filter 'status=running' \
        --format '{{.ID}}'
}

_events() {
    docker events \
        --filter 'type=container' \
        --filter 'event=die' \
        --filter 'event=kill' \
        --filter 'event=pause' \
        --filter 'event=restart' \
        --filter 'event=start' \
        --filter 'event=stop' \
        --filter 'event=unpause' \
        --format '{{json .}}'
}

_buildHostLine() {
    docker inspect \
        --format \
        $'
        {{- range .NetworkSettings.Networks -}}
            {{- if .IPAddress -}}
                {{- .IPAddress }} {{index (split $.Name "/") 1}} {{join .Aliases " "}}{{ println -}}
            {{- end -}}
        {{- end -}}
        ' \
        "$1"
}

_sanitizeRegex() {
    sed 's:[\/&]:\\&:g;$!s/$/\\/'
}

_buildLines() {
    local ids="${@:-$(_containerIds)}"
    for id in $ids; do
        hostLine="$(_buildHostLine "$id")"
        if [[ -n "$hostLine" ]]; then
            hostLines["_$id"]="$hostLine"
        else
            unset hostLines["_$id"]
        fi
    done
    _saveToHosts
}

_defaultHosts() {
    local contents
    contents="$(sed -n "/$(_sanitizeRegex <<< "$BEGINNING_PATTERN")/q;p" < "$FILE" | sed '${/^$/d;}')"
    case "${1:-}" in
        -w)
            printf '%s\n' "$contents" > "$FILE" ;;
        *)
            printf '%s' "$contents" ;;
    esac
}

_saveToHosts() {
    local defaultHosts lines
    defaultHosts="$(_defaultHosts)"
    lines="$(printf '%s\n' "${hostLines[@]}" | grep .)"
    printf "%s\n\n%s\n%s\n%s\n" "$defaultHosts" "$BEGINNING_PATTERN" "$lines" "$ENDING_PATTERN" > "$FILE"
}

_main() {
    set -euo pipefail
    trap '_handle' SIGINT SIGTERM

    _log 'Adding all containers to "%s"' "$FILE"
    _buildLines
    _log 'Listening for events'
    while true; do
        while read -r event; do
            _log 'Change triggered due to %s' \
                "$(jq -r '"\(.Action) event on \"\(.Actor.Attributes.name)\""' <<< "$event")"
            _buildLines "$(jq -r .id <<< "$event")"
        done < <(_events)
    done
}

if [[ "$0" = "$BASH_SOURCE" ]]; then
    _main "$@"
fi
