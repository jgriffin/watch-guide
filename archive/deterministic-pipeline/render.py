#!/usr/bin/env python3
"""Thin matchday-sheet renderer.

The TEMPLATE owns the layout: template.html holds the full <style> CSS and the
entire page structure as Jinja loops/conditionals over a `data` context whose
shape matches the content JSON. This script just loads template + content,
wires up a few data-prep filters, and writes index.html next to the content file.

  uv run --with jinja2 render.py matches/egypt-iran/content.json

To restyle, edit template.html. To correct facts, edit the content JSON.
"""

import html
import json
import os
import re
import sys

from jinja2 import Environment, FileSystemLoader

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CONTENT = os.path.join(HERE, "matches", "egypt-iran", "content.json")


# --- data-prep filters (the only genuine logic kept in Python) --------------

def esc(value):
    """HTML-escape a data value (quotes left intact); empty/None -> ''."""
    if value is None:
        return ""
    return html.escape(str(value), quote=False)


def shirt(num):
    """Shirt-number display: strip trailing '?', neutral dash if unknown."""
    s = "" if num is None else str(num).strip()
    if s.endswith("?"):
        s = s[:-1].strip()
    if s == "" or s == "?":
        return "–"
    return s


def _num_sort_key(num):
    """Leading integer of a shirt value; unknown/'?' sorts last."""
    m = re.match(r"\d+", shirt(num))
    return int(m.group()) if m else float("inf")


def numsort(players):
    """Sort a roster list by shirt number (unknown last; stable)."""
    return sorted(players or [], key=lambda p: _num_sort_key(p.get("num")))


def paren(text):
    """Contents of a trailing parenthetical, or '' if none."""
    m = re.search(r"\(([^)]*)\)\s*$", str(text or ""))
    return m.group(1).strip() if m else ""


def strip_paren(text):
    """The string with any trailing parenthetical removed."""
    return re.sub(r"\s*\([^)]*\)\s*$", "", str(text or "")).strip()


def first_token(text, *seps):
    """First chunk of a delimited string, trimmed (default seps: / + ,)."""
    s = str(text or "")
    for sep in (seps or ("/", "+", ",")):
        s = s.split(sep)[0]
    return s.strip()


# --- assembly ---------------------------------------------------------------

def render(data):
    env = Environment(
        loader=FileSystemLoader(HERE),
        autoescape=False,
        trim_blocks=True,
        lstrip_blocks=True,
    )
    env.filters.update(
        esc=esc, shirt=shirt, numsort=numsort,
        paren=paren, strip_paren=strip_paren, first_token=first_token,
    )

    match = data.get("match", {})
    # Pre-computed fields the template can't cleanly derive (regex extraction).
    xi_numbers = {
        p.get("name"): p.get("num")
        for team in data.get("teams", {}).values()
        for p in team.get("xi", [])
    }
    md = re.search(r"Matchday\s*(\d+)", match.get("stage", ""))
    yr = re.search(r"(\d{4})", match.get("competition", ""))
    years = re.findall(r"\b\d{4}\b", data.get("headToHead", {}).get("summary", ""))

    return env.get_template("template.html").render(
        data=data,
        xi_numbers=xi_numbers,
        matchday=md.group(1) if md else "",
        year2=yr.group(1)[2:] if yr else "",
        last_met=max(years) if years else "",
    )


def main():
    content_path = (
        os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CONTENT
    )
    with open(content_path, encoding="utf-8") as f:
        data = json.load(f)
    out_path = os.path.join(os.path.dirname(content_path), "index.html")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(render(data))
    print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
