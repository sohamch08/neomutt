#!/usr/bin/env python3
"""Render HTML mail as UTF-8 text without hidden preview or tracking clutter."""

import html
from html.parser import HTMLParser
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import textwrap


VOID_TAGS = {"area", "base", "br", "col", "embed", "hr", "img", "input",
             "link", "meta", "param", "source", "track", "wbr"}
DROP_TAGS = {"head", "script", "style", "noscript", "template", "iframe",
             "object", "svg"}
KEEP_TAGS = {"a", "b", "blockquote", "br", "code", "dd", "div", "dl", "dt",
             "em", "h1", "h2", "h3", "h4", "h5", "h6", "hr", "i", "li",
             "ol", "p", "pre", "span", "strong", "table", "tbody", "td",
             "th", "thead", "tr", "u", "ul"}
HIDDEN_STYLE = re.compile(
    r"display\s*:\s*none\b|visibility\s*:\s*hidden\b|mso-hide\s*:\s*all\b|"
    r"max-height\s*:\s*0(?:px|pt|em|rem|%)?(?:\s*!important)?\s*(?:;|$)",
    re.I,
)
PREHEADER = re.compile(
    r"(?:^|[\s_-])(?:preheader|preview[-_]?text|mcnpreviewtext)(?:$|[\s_-])",
    re.I,
)
PADDING_ENTITY = re.compile(
    r"&(?:nbsp|#0*(?:160|847|8203|8288|65279)|"
    r"#x0*(?:a0|34f|200b|2060|feff));", re.I,
)
INVISIBLE_PADDING = str.maketrans({"\u00a0": " ", "\u034f": None,
                                      "\u200b": None, "\u2060": None,
                                      "\ufeff": None})


def clean_text(text):
    # Some bulk senders double-encode invisible inbox-preview padding.
    return PADDING_ENTITY.sub(" ", text).translate(INVISIBLE_PADDING)


class MailHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.output = []
        self.images = 0

    @property
    def hidden(self):
        return bool(self.stack and self.stack[-1][1])

    def handle_starttag(self, tag, attrs):
        attrs = {name: value or "" for name, value in attrs}
        suppressed = (
            self.hidden or tag in DROP_TAGS or "hidden" in attrs
            or attrs.get("aria-hidden", "").lower() == "true"
            or HIDDEN_STYLE.search(attrs.get("style", ""))
            or PREHEADER.search(" ".join(
                (attrs.get("class", ""), attrs.get("id", ""))))
        )
        if tag not in VOID_TAGS:
            self.stack.append((tag, bool(suppressed)))
        if suppressed:
            return
        if tag == "img":
            alt = clean_text(attrs.get("alt", "")).strip()
            filename = re.search(r"\.(?:jpe?g|png|gif|webp|svg)(?:\?.*)?$", alt, re.I)
            tracking = all(attrs.get(size, "").strip() in {"0", "1", "0px", "1px"}
                           for size in ("width", "height"))
            if not tracking:
                self.images += 1
            if alt and not filename and not tracking:
                self.output.append(" " + html.escape(alt) + " ")
        elif tag in KEEP_TAGS:
            extra = ""
            href = attrs.get("href", "")
            if tag == "a" and re.match(r"^(?:https?://|mailto:|ftp://|#)", href, re.I):
                extra = ' href="' + html.escape(href, quote=True) + '"'
            self.output.append("<" + tag + extra + ">")

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID_TAGS:
            self.handle_endtag(tag)

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                removed = self.stack[index:]
                del self.stack[index:]
                for name, suppressed in reversed(removed):
                    if not suppressed and name in KEEP_TAGS:
                        self.output.append("</" + name + ">")
                break

    def handle_data(self, data):
        if not self.hidden:
            verbatim = any(name in {"pre", "code"} for name, _ in self.stack)
            self.output.append(html.escape(data if verbatim else clean_text(data)))


def decode_html(data):
    match = re.search(br"charset\s*=\s*[\"']?\s*([a-zA-Z0-9_.-]+)", data[:8192])
    candidates = [match.group(1).decode("ascii")] if match else []
    for encoding in candidates + ["utf-8-sig", "windows-1252"]:
        try:
            return data.decode(encoding)
        except (LookupError, UnicodeDecodeError):
            pass
    return data.decode("utf-8", errors="replace")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: render-html.py HTML_FILE")
    lynx = shutil.which("lynx")
    if not lynx:
        raise SystemExit("HTML rendering requires lynx: brew install lynx")
    parser = MailHTML()
    parser.feed(decode_html(Path(sys.argv[1]).read_bytes()))
    parser.close()
    try:
        width = max(20, min(500, int(os.environ.get("COLUMNS", "80"))))
    except ValueError:
        width = 80
    result = subprocess.run(
        [lynx, "-stdin", "-dump", "-localhost", "-nolist", "-nonumbers",
         "-display_charset=utf-8", "-assume_charset=utf-8", f"-width={width}"],
        input="<html><body>" + "".join(parser.output) + "</body></html>",
        encoding="utf-8", stdout=subprocess.PIPE, check=True,
    )
    text = re.sub(r"\n[ \t]*\n(?:[ \t]*\n)+", "\n\n", result.stdout)
    if parser.images:
        note = "[Images omitted. Open the HTML attachment in your browser to view the full email.]"
        text = text.rstrip() + "\n\n" + textwrap.fill(note, width=width) + "\n"
    sys.stdout.buffer.write((text.strip() + "\n").encode("utf-8"))


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"HTML rendering failed: {error}") from error
