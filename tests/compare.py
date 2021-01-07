#!/usr/bin/env python3

import csv
import sys


def get_changes(a, b):
    row_idx = 0
    changed = []
    for a_row in a:
        if row_idx >= len(b):
            changed.append(a_row)
            row_idx += 1
            continue
        b_row = b[row_idx]
        for k, a_val in a_row.items():
            b_val = b_row.get(k)
            if not a_val:
                a_val = ""
            if not b_val:
                b_val = ""
            if b_val != a_val:
                changed.append(a_row)
                break
        row_idx += 1
    return changed


def get_rows(table):
    rows = []
    with open(table, "r") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            rows.append(row)
    return rows


args = sys.argv
left = args[1]
right = args[2]

left_rows = sorted(get_rows(left), key=lambda r: (r["table"], r["cell"]))
right_rows = sorted(get_rows(right), key=lambda r: (r["table"], r["cell"]))

removed = get_changes(left_rows, right_rows)
added = get_changes(right_rows, left_rows)

diff = []
if removed:
    diff.append("\nRemoved:")
    for row in removed:
        vals = ["" if x is None else x for x in row.values()]
        diff.append("---\t" + "\t".join(vals))
if added:
    diff.append("\nAdded:")
    for row in added:
        vals = ["" if x is None else x for x in row.values()]
        diff.append("+++\t" + "\t".join(vals))

if diff:
    print("\n".join(diff))
    sys.exit(1)
