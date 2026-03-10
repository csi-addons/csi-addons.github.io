#!/usr/bin/env python3
"""Extract a short description from a CSI-Addons spec feature README.md."""

import re
import sys


def clean(text):
    """Clean markdown formatting and limit length."""
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"[*_`]", "", text)
    text = text.replace("\n", " ").strip()
    text = re.sub(r"\s+", " ", text)
    if len(text) > 200:
        text = text[:197] + "..."
    return text


def extract(content):
    """Extract best description from README content."""
    # Try the Objective section first
    obj_match = re.search(
        r"##\s*Objective\s*\n+(.*?)(?=\n##|\Z)", content, re.DOTALL
    )
    if obj_match:
        text = obj_match.group(1).strip()
        text = re.split(r"\n\s*\n", text)[0]
        result = clean(text)
        if len(result) > 30:
            return result

    # Try headings that typically contain the main description
    for heading in ["Container Storage Interface", "Solution Overview"]:
        match = re.search(
            r"##[#]*\s*" + heading + r"\s*\n+(.*?)(?=\n##|\Z)", content, re.DOTALL
        )
        if match:
            text = match.group(1).strip()
            text = re.split(r"\n\s*\n", text)[0]
            if not text.startswith("```"):
                result = clean(text)
                if len(result) > 30:
                    return result

    # Fallback: first substantial paragraph after any heading
    lines = content.split("\n")
    started = False
    paragraph = []
    for line in lines:
        if line.startswith("#"):
            if paragraph:
                text = " ".join(paragraph)
                result = clean(text)
                if len(result) > 30:
                    return result
            started = True
            paragraph = []
            continue
        if started:
            if line.strip() == "" and paragraph:
                text = " ".join(paragraph)
                result = clean(text)
                if len(result) > 30:
                    return result
                paragraph = []
            elif line.strip() and not line.strip().startswith("```"):
                paragraph.append(line.strip())

    if paragraph:
        return clean(" ".join(paragraph))

    return "Storage operation provided by the CSI-Addons specification."


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <README.md>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], "r") as f:
        content = f.read()

    print(extract(content))
