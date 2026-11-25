# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
"""Checks the quotes in a decision's "Tankun's words" against the design session's transcript.

Every quote must be one of Tankun's messages, whole and exact, or, after "asked", a stretch of one of the design
session's own messages. Elsewhere in the entry, a quote right after "Tankun:" must be one of his whole messages.
Line breaks and runs of spaces count as one space, since DECISIONS.md wraps its lines. A "has code" or "too long"
marker may stand only for a message with a code block or over 300 characters, among Tankun's messages since the
previous decision's answer.

    python3 -I design/check-quotes.py TRANSCRIPT.jsonl [DECISION_NUMBER] [--log OTHER/DECISIONS.md] [--subject SUBJECT]

With no number, it checks the newest decision. `--log` checks another project's decision log, such as Seal's.
`--subject` also checks the decision's commit subject: its `(owner: …)` part must quote the answer whole, or, when the
answer has any backtick or runs over 60 characters, write `has code` or `too long` instead, as IMPLEMENTATION.md says.
It exits with status 0 when everything matches, 1 otherwise.
"""

import json
import re
import sys
from pathlib import Path


def squash(text):
    return re.sub(r"\s+", " ", text).strip()


def read_transcript(path):
    owner, design, raw, events = [], [], [], []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        row = json.loads(line)
        content = row.get("message", {}).get("content")
        if row.get("type") == "user" and isinstance(content, str):
            # Tankun's own messages are plain strings; tool results, notices and summaries aren't, or start with a tag.
            if not content.startswith("<") and not content.startswith("This session is being continued"):
                owner.append(squash(content))
                raw.append(content.strip())
                events.append(("owner", content.strip()))
        elif row.get("type") == "assistant" and isinstance(content, list):
            texts = [squash(part["text"]) for part in content if part.get("type") == "text"]
            design.extend(texts)
            events.extend(("design", text) for text in texts)
    return owner, design, raw, events


def words_of(decisions, number):
    sections = re.split(r"(?m)^## (?=D\d+\. )", decisions)
    wanted = [s for s in sections if number is None or s.startswith(f"D{number}. ")]
    if not wanted:
        sys.exit(f"no decision D{number}")
    section = wanted[-1]
    start = section.find("**Tankun's words.**")
    if start < 0:
        sys.exit(f"{section.split(chr(10))[0]}: no Tankun's words")
    index = sections.index(section)
    before = sections[index - 1] if index > 1 else ""
    earlier = before[before.find("**Tankun's words.**") :] if "**Tankun's words.**" in before else ""
    return (
        section.split("\n")[0],
        squash(section[:start]),
        squash(section[start + len("**Tankun's words.**") :]),
        squash(earlier),
    )


def answer_at(words, events):
    """Where in the conversation the owner answered this entry's question: the first of Tankun's messages after the
    design session last asked it. None when the entry asks nothing."""
    asked = re.findall(r'asked "(.*?)", the owner chose', words, re.IGNORECASE)
    if not asked:
        return None
    question = asked[-1]
    asking = [i for i, (who, text) in enumerate(events) if who == "design" and question in text]
    if not asking:
        return None
    return next((i for i in range(asking[-1] + 1, len(events)) if events[i][0] == "owner"), None)


def main():
    args = sys.argv[1:]
    log = Path(__file__).resolve().parent.parent / "DECISIONS.md"
    if "--log" in args:
        at = args.index("--log")
        if at + 1 >= len(args):
            sys.exit(__doc__)
        log = Path(args[at + 1])
        del args[at : at + 2]
    subject = None
    if "--subject" in args:
        at = args.index("--subject")
        if at + 1 >= len(args):
            sys.exit(__doc__)
        subject = args[at + 1]
        del args[at : at + 2]
    if len(args) not in (1, 2):
        sys.exit(__doc__)
    owner, design, raw, events = read_transcript(args[0])
    number = int(args[1]) if len(args) == 2 else None
    decisions = log.read_text(encoding="utf-8")
    title, body, words, earlier = words_of(decisions, number)

    # Take out Tankun's whole messages first, longest first, so a quote holding quote marks of its own still matches.
    rest = words
    for message in sorted(set(owner), key=len, reverse=True):
        rest = rest.replace(f'"{message}"', " ")
    problems = []
    # The design session's question runs from `asked "` to `", the owner chose`, so it may hold quote marks itself.
    def question(found):
        if not any(found.group(1) in text for text in design):
            problems.append(found.group(1))
        return " "

    rest = re.sub(r'asked "(.*?)", the owner chose', question, rest)
    # Whatever is still quoted must be the design session's question, right after "asked".
    for found in re.finditer(r'"([^"]*)"', rest):
        quote = found.group(1)
        asked = rest[: found.start()].rstrip().lower().endswith("asked")
        if not (asked and quote and any(quote in text for text in design)):
            problems.append(quote)

    # Elsewhere in the entry, a quote right after "Tankun:" must be one of Tankun's whole messages too.
    for found in re.finditer(r'Tankun: "', body):
        if not any(body.startswith(f'"{message}"', found.end() - 1) for message in owner):
            problems.append(body[found.end() : found.end() + 60] + "…")

    # A marker may stand only for a message that can't be quoted: one with a code block, or over 300 characters. Count
    # the markers against such messages since the previous decision's last quote, up to this decision's last quote.
    markers = len(re.findall(r"\b(?:has code|too long)\b", rest))
    end = answer_at(words, events)
    if markers and end is not None:
        start = answer_at(earlier, events)
        start = start + 1 if start is not None and start < end else 0
        window = [text for who, text in events[start : end + 1] if who == "owner"]
        unquotable = sum(1 for message in window if "```" in message or len(message) > 300)
        if markers > unquotable:
            problems.append(
                f"{markers} has code or too long marker(s), but only {unquotable} message(s) since the previous "
                "decision have a code block or run over 300 characters: quote the others whole"
            )

    subject_problems = []
    if subject is not None:
        found = re.search(r'\(owner: (?:"(.*)"|(has code|too long)); D\d+', subject)
        end = answer_at(words, events)
        if not found:
            subject_problems.append("the subject has no (owner: …; D…) part")
        elif end is None:
            subject_problems.append("the entry asks no question, so the subject's answer can't be checked")
        else:
            answer = events[end][1]
            wanted = "has code" if "`" in answer else "too long" if len(answer) > 60 else None
            if wanted and found.group(2) != wanted:
                subject_problems.append(f"the subject should write {wanted} for the answer, not quote it")
            if not wanted and found.group(1) != answer:
                subject_problems.append(f'the subject should quote the answer whole: "{answer}"')

    print(title)
    for quote in problems:
        print(f'  not a whole message of Tankun\'s, nor the design session\'s words: "{quote}"')
    for problem in subject_problems:
        print(f"  commit subject: {problem}")
    if problems or subject_problems:
        sys.exit(1)
    print("  every quote matches" + (", and the commit subject too" if subject is not None else ""))


if __name__ == "__main__":
    main()
