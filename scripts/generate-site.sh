#!/usr/bin/env bash
#
# generate-site.sh - Generate the CSI-Addons website from spec and
# kubernetes-csi-addons repositories.
#
# Usage: ./scripts/generate-site.sh [SPEC_DIR] [K8S_DIR]
#
# The script reads proto files from the spec repo to extract RPC operations,
# reads README.md files for feature descriptions, discovers CRD types from
# the kubernetes-csi-addons API directory, and assembles index.html from
# the template.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SPEC_DIR="${1:-${ROOT_DIR}/_repos/spec}"
K8S_DIR="${2:-${ROOT_DIR}/_repos/kubernetes-csi-addons}"

TEMPLATE="${ROOT_DIR}/templates/index.html.tpl"
FEATURES_JSON="${ROOT_DIR}/data/features.json"
OUTPUT="${ROOT_DIR}/index.html"

# Preferred display order for known features. Any new features discovered in the
# spec repo that are not in this list are appended automatically.
KNOWN_ORDER="replication reclaimspace fence volumegroup encryptionkeyrotation identity"

# Directories in the spec repo that are NOT features (infrastructure/build dirs)
SKIP_DIRS="bin dist extras google images lib release-tools .github"

# Verify dependencies
for cmd in python3 git; do
    if ! command -v "${cmd}" &>/dev/null; then
        echo "ERROR: ${cmd} is required but not found" >&2
        exit 1
    fi
done

# GNU grep is required for -P (Perl regex) support
if command -v ggrep &>/dev/null; then
    GREP="ggrep"
elif grep --version 2>/dev/null | grep -q GNU; then
    GREP="grep"
else
    echo "ERROR: GNU grep is required (for -P support)." >&2
    echo "On macOS, install it with: brew install grep" >&2
    exit 1
fi

# Verify repos exist
if [[ ! -d "${SPEC_DIR}" ]]; then
    echo "ERROR: spec repo not found at ${SPEC_DIR}" >&2
    echo "Run 'make sync-repos' first, or pass the path as argument." >&2
    exit 1
fi
if [[ ! -d "${K8S_DIR}" ]]; then
    echo "ERROR: kubernetes-csi-addons repo not found at ${K8S_DIR}" >&2
    echo "Run 'make sync-repos' first, or pass the path as argument." >&2
    exit 1
fi

# --- Auto-discover feature directories from the spec repo ---
# Returns features in preferred order, appending any new ones found
discover_features() {
    local all_dirs=""
    for dir in "${SPEC_DIR}"/*/; do
        local name
        name="$(basename "${dir}")"
        # Skip non-feature directories
        local skip=false
        for s in ${SKIP_DIRS}; do
            if [[ "${name}" == "${s}" ]]; then
                skip=true
                break
            fi
        done
        if [[ "${skip}" == "true" ]]; then
            continue
        fi
        # Must contain a proto file to be a feature
        if find "${dir}" -maxdepth 1 -name '*.proto' ! -name '*.tmp' 2>/dev/null | grep -q .; then
            all_dirs="${all_dirs} ${name}"
        fi
    done

    # Build ordered list: known features first, then any new ones
    local ordered=""
    for feature in ${KNOWN_ORDER}; do
        if echo "${all_dirs}" | grep -qw "${feature}"; then
            ordered="${ordered} ${feature}"
        fi
    done
    # Append any features not in KNOWN_ORDER
    for feature in ${all_dirs}; do
        if ! echo "${ordered}" | grep -qw "${feature}"; then
            ordered="${ordered} ${feature}"
        fi
    done
    echo "${ordered}" | xargs
}

# --- Extract the latest release tag from kubernetes-csi-addons ---
get_latest_release() {
    git -C "${K8S_DIR}" tag --sort=-version:refname 2>/dev/null \
        | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
        | head -1
}

# --- Extract RPC names from a proto file ---
# Returns space-separated list of RPC names
extract_rpcs() {
    local proto_file="$1"
    ${GREP} -oP '^\s*rpc\s+\K[A-Za-z]+' "${proto_file}" 2>/dev/null || true
}

# --- Extract the Objective section from a feature README ---
# Falls back to the first paragraph after the title
extract_description() {
    local readme="$1"
    python3 "${SCRIPT_DIR}/extract_description.py" "${readme}"
}

# --- Read a JSON field from features.json ---
json_field() {
    local key="$1"
    local field="$2"
    python3 -c "
import json, sys
with open('${FEATURES_JSON}') as f:
    data = json.load(f)
entry = data.get('${key}', {})
print(entry.get('${field}', ''))
"
}

# --- Discover CRD kind names from kubernetes-csi-addons API types ---
extract_crds() {
    local api_dir="${K8S_DIR}/api"
    if [[ ! -d "${api_dir}" ]]; then
        echo "CSIAddonsNode"
        return
    fi
    # Find all types marked with kubebuilder:object:root=true (these are CRD kinds)
    grep -rh 'kubebuilder:object:root=true' "${api_dir}" -A10 2>/dev/null \
        | ${GREP} -P '^type\s+[A-Z]' \
        | ${GREP} -oP '^type\s+\K[A-Z][A-Za-z]+' \
        | grep -v 'List$' \
        | sort -u
}

# --- Generate feature cards HTML ---
generate_features_html() {
    local html=""
    for feature in ${FEATURE_LIST}; do
        local feature_dir="${SPEC_DIR}/${feature}"
        if [[ ! -d "${feature_dir}" ]]; then
            continue
        fi

        local title
        title="$(json_field "${feature}" "title")"
        if [[ -z "${title}" ]]; then
            # Auto-generate title from directory name
            title="$(echo "${feature}" | sed 's/\b\(.\)/\u\1/g')"
        fi

        local icon_class
        icon_class="$(json_field "${feature}" "icon_class")"
        local icon_svg
        icon_svg="$(json_field "${feature}" "icon_svg")"

        # Extract description from README
        local description=""
        local readme="${feature_dir}/README.md"
        if [[ -f "${readme}" ]]; then
            description="$(extract_description "${readme}")"
        fi
        if [[ -z "${description}" ]]; then
            description="Storage operation provided by the CSI-Addons specification."
        fi

        # Extract RPCs from proto file
        local rpcs=""
        local proto_file
        proto_file="$(find "${feature_dir}" -name '*.proto' ! -name '*.tmp' 2>/dev/null | head -1)"
        if [[ -n "${proto_file}" ]]; then
            rpcs="$(extract_rpcs "${proto_file}")"
        fi

        # Build the RPC list as a subtitle
        local rpc_info=""
        if [[ -n "${rpcs}" ]]; then
            local rpc_list
            rpc_list="$(echo "${rpcs}" | tr ' ' '\n' | sed 's/\([A-Z]\)/ \1/g;s/^ //' | paste -sd',' - | sed 's/,/, /g')"
            rpc_info="<br><small class=\"feature-rpcs\">Operations: ${rpc_list}</small>"
        fi

        # Default icon if not in features.json
        if [[ -z "${icon_svg}" ]]; then
            icon_svg='<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="8" y="8" width="32" height="32" rx="4" stroke="currentColor" stroke-width="2.5"/><path d="M18 24h12M24 18v12" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"/></svg>'
            icon_class="icon-default"
        fi

        html="${html}
        <div class=\"feature-card\">
          <div class=\"feature-icon ${icon_class}\">
            ${icon_svg}
          </div>
          <h3>${title}</h3>
          <p>${description}${rpc_info}</p>
        </div>
"
    done
    echo "${html}"
}

# --- Find the documentation file for a CRD kind ---
# Looks for a matching .md file in the docs/ directory of kubernetes-csi-addons
find_crd_doc() {
    local crd="$1"
    local docs_dir="${K8S_DIR}/docs"
    if [[ ! -d "${docs_dir}" ]]; then
        return
    fi
    # Convert CRD kind to lowercase for matching (e.g. ReclaimSpaceJob -> reclaimspacejob)
    local lower
    lower="$(echo "${crd}" | tr '[:upper:]' '[:lower:]')"
    # Check for exact match first
    if [[ -f "${docs_dir}/${lower}.md" ]]; then
        echo "${lower}.md"
        return
    fi
    # Check for partial match (e.g. ReclaimSpaceCronJob -> reclaimspace.md)
    for doc in "${docs_dir}"/*.md; do
        local basename
        basename="$(basename "${doc}" .md)"
        if [[ "${lower}" == "${basename}"* ]]; then
            echo "$(basename "${doc}")"
            return
        fi
    done
}

# --- Generate CRD list HTML ---
generate_crds_html() {
    local crds
    crds="$(extract_crds)"
    local html=""
    local docs_base="https://github.com/csi-addons/kubernetes-csi-addons/blob/main/docs"
    while IFS= read -r crd; do
        if [[ -n "${crd}" ]]; then
            local doc_file
            doc_file="$(find_crd_doc "${crd}")"
            if [[ -n "${doc_file}" ]]; then
                html="${html}            <li><a href=\"${docs_base}/${doc_file}\" target=\"_blank\" rel=\"noopener\">${crd}</a></li>
"
            else
                html="${html}            <li>${crd}</li>
"
            fi
        fi
    done <<< "${crds}"
    echo "${html}"
}

# --- Assemble the final HTML ---
echo "Generating CSI-Addons website..."
echo "  Spec repo:    ${SPEC_DIR}"
echo "  K8s repo:     ${K8S_DIR}"
echo "  Template:     ${TEMPLATE}"
echo ""

# Discover features from spec repo
FEATURE_LIST="$(discover_features)"

# Get latest release
LATEST_RELEASE="$(get_latest_release)"
if [[ -z "${LATEST_RELEASE}" ]]; then
    LATEST_RELEASE="v0.14.0"
    echo "  Warning: Could not determine latest release, using ${LATEST_RELEASE}"
else
    echo "  Latest release: ${LATEST_RELEASE}"
fi

# Generate dynamic sections
FEATURES_HTML="$(generate_features_html)"
CRDS_HTML="$(generate_crds_html)"

echo "  Features found: ${FEATURE_LIST}"

CRD_COUNT="$(extract_crds | wc -l)"
echo "  CRDs found: ${CRD_COUNT}"
echo ""

# Write generated fragments to temp files for safe python processing
FEATURES_TMP="$(mktemp)"
CRDS_TMP="$(mktemp)"
trap 'rm -f "${FEATURES_TMP}" "${CRDS_TMP}"' EXIT

echo "${FEATURES_HTML}" > "${FEATURES_TMP}"
echo "${CRDS_HTML}" > "${CRDS_TMP}"

# Build the output by replacing markers in the template
cp "${TEMPLATE}" "${OUTPUT}"

# Replace release version placeholder
sed -i "s|{{LATEST_RELEASE}}|${LATEST_RELEASE}|g" "${OUTPUT}"

# Replace marker sections using python (handles multi-line content safely)
python3 - "${OUTPUT}" "${FEATURES_TMP}" "${CRDS_TMP}" <<'PYEOF'
import sys

output_file = sys.argv[1]
features_file = sys.argv[2]
crds_file = sys.argv[3]

with open(output_file, 'r') as f:
    content = f.read()

with open(features_file, 'r') as f:
    features_html = f.read()

with open(crds_file, 'r') as f:
    crds_html = f.read()

def replace_marker(content, begin_marker, end_marker, replacement):
    start_idx = content.index(begin_marker) + len(begin_marker)
    end_idx = content.index(end_marker)
    return content[:start_idx] + "\n" + replacement + content[end_idx:]

content = replace_marker(content, "<!-- BEGIN:FEATURES -->", "<!-- END:FEATURES -->", features_html)
content = replace_marker(content, "<!-- BEGIN:CRDS -->", "<!-- END:CRDS -->", crds_html)

with open(output_file, 'w') as f:
    f.write(content)
PYEOF

echo "Generated ${OUTPUT}"
echo "Done."
