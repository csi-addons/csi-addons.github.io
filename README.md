# CSI-Addons Website

The website for the [CSI-Addons][csi-addons] project. It is hosted at
[csi-addons.github.io](https://csi-addons.github.io).

## How the Site is Generated

The website content is dynamically generated from the upstream repositories:

- **[csi-addons/spec][spec]**: Feature descriptions and RPC operations are
  extracted from proto files and README.md files.
- **[csi-addons/kubernetes-csi-addons][kubernetes-csi-addons]**: CRD types and
  the latest release version are discovered automatically.

The site is assembled by the `scripts/generate-site.sh` script, which populates
the `templates/index.html.tpl` template with the extracted content and writes
the final `index.html`.

A GitHub Actions workflow (`.github/workflows/update-site.yml`) runs weekly to
regenerate the site and open a pull request if content has changed.

## Development

### Prerequisites

- Bash
- Python 3
- GNU grep (on macOS: `brew install grep`)
- Git

### Generate the Site Locally

```bash
# Clone repos and generate index.html
make generate

# Preview in browser
make serve
```

You can also point to local checkouts of the source repos:

```bash
make generate SPEC_DIR=../spec K8S_DIR=../kubernetes-csi-addons
```

Run `make help` for all available targets.

### Project Structure

- `templates/index.html.tpl` - HTML template with placeholder markers
- `scripts/generate-site.sh` - Main generation script
- `scripts/extract_description.py` - Extracts descriptions from spec READMEs
- `data/features.json` - Feature metadata (titles and custom inline SVG icons)
- `css/style.css` - Stylesheet
- `js/main.js` - Client-side JavaScript (tabs, copy buttons, navigation)
- `index.html` - Generated output (do not edit directly)

### Icons

The feature icons in `data/features.json` are custom inline SVGs designed for
this site. They are not based on an external icon set like Font Awesome.

## Contact Information

An [open and public mailinglist][list] is available for discussions and
questions. The messages on the list are [archived][list_archive] for reference.
Viewing the archives requires joining the list with a Google account.

[csi-addons]: https://github.com/csi-addons
[spec]: https://github.com/csi-addons/spec
[kubernetes-csi-addons]: https://github.com/csi-addons/kubernetes-csi-addons
[list]: https://groups.google.com/a/redhat.com/g/csi-addons/about
[list_archive]: https://groups.google.com/a/redhat.com/g/csi-addons
