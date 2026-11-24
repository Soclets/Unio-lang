# Checks Ralph's answers for reading and showing `Float`s, printed by floats.ml, against Python's own `float`,
# `repr` and `decimal`, as the tests' check.py files do (D12): a second language's opinion of the answer.
import sys
from decimal import Decimal, ROUND_HALF_UP, getcontext

getcontext().prec = 2000

def shown(x):
    if x == 0:
        return "0.0"
    short = Decimal(repr(x))
    text = format(short, "f")
    if "." not in text:
        text += ".0"
    if short == Decimal(x):
        return text
    return "UNDECIDED" if x < 0 else "~" + text

def places(x, n):
    text = str(Decimal(x).quantize(Decimal(1).scaleb(-n), rounding=ROUND_HALF_UP))
    # D176: a value that rounds to zero shows no minus.
    return text[1:] if text.startswith("-") and Decimal(text) == 0 else text

PLACES = [0, 1, 2, 3, 5]
problems = 0
cases = 0
for line in open(sys.argv[1]).read().splitlines():
    fields = line.split("|")
    cases += 1
    if fields[0] == "read":
        text = fields[1]
        try:
            x = float(text)
        except OverflowError:
            x = None
        if fields[2] == "TOO_BIG":
            ok = x is None or x == float("inf")
        else:
            want = [shown(x), str(Decimal(text) == Decimal(x)).lower()] + [places(x, n) for n in PLACES]
            ok = fields[2:] == want
    else:
        a, op, b = float(fields[1]), fields[2], float(fields[3])
        try:
            z = {"+": lambda: a + b, "-": lambda: a - b, "*": lambda: a * b, "/": lambda: a / b}[op]()
        except ZeroDivisionError:
            z = "BY_ZERO"
        if fields[4] == "TOO_BIG":
            ok = z == float("inf") or z == float("-inf")
        elif fields[4] == "BY_ZERO":
            ok = z == "BY_ZERO"
        else:
            want = [shown(z)] + [places(z, n) for n in PLACES]
            ok = z not in (float("inf"), float("-inf")) and fields[4:] == want
    if not ok:
        problems += 1
        if problems <= 10:
            print("differs:", line)
print(f"{cases} cases, {problems} differ from Python")
sys.exit(1 if problems else 0)
