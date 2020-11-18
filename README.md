# VALVE is A Lightweight Validation Engine

This repository will contain documentation and tests common to different VAVLE implementations.
So far we're working on:

- [valve.py](https://github.com/ontodev/valve.py)
- [valve.js](https://github.com/ontodev/valve.js)

## Configuration Files

Two VALVE configuration files (as TSV or CSV) are required:
* `datatype`
* `field`

You may also include an optional `rule` table.

These can be passed as individual files to the input, or you can pass a directory containing these files. We list the required and optional headers below, but you are welcome to include any other headers you find helpful (e.g., `note`). These will be ignored by VALVE.

### Datatype Table

Datatypes allow you to define regex patterns for cell values. The datatypes are a hierarchy of types, and when a datatype is provided as a `condition`, all parent values are also checked.

The datatype table can have the following fields (a `*` indicates that it is a required field):
* `datatype` \*: name of datatype - a single word that uses any alphanumeric character or `-` and `_`
* `parents` \*: parent or parents datatype - multiple parents may be provided in a space-separated list
* `match`\*: regex match (this may be left blank)
* `level` \*: validation fail level when a value does not meet the regex match (info, warn, or error)
* `description`: brief description of datatype
* `instructions`: how to fix problems
* `replace`: regex automatic replacement

The regex patterns should be enclosed with forward slashes (e.g., `/^$/` matches blanks). Replacements should be formatted like `perl` replacements (e.g., `s/\n/ /g` replaces newlines with spaces).

[Example datatype table](https://github.com/ontodev/valve.py/blob/main/tests/resources/inputs/datatype.tsv)

### Field Table

The field table allows you to define checks for the contents of columns.

The field table requires the following fields (a `*` indicates that it is a required field):
* `table` \*: table name within inputs
* `column` \*: column name within table
* `condition` \*: function or datatype to validate

All contents of the `table.column` are validated against the `condition`.

[Example field table](https://github.com/ontodev/valve.py/blob/main/tests/resources/inputs/field.tsv)

### Rule Table

The rule table allows you to define more complex "when" rules.

The rule table requires the following fields (a `*` indicates that it is a required field):
* `table` \*: table name within inputs
* `when column` \*: column name within the table
* `when condition` \*: condition to check contents of "when table"."when column" against
* `then column` \*: column name within the table
* `then condition` \*: datatype or function to validate when "when condition" returns true
* `level`: validation fail level when the "then condition" fails (info, warn, or error)
* `description`: description of failure, included in message

If the contents of the `"when table"."when column"` do not pass the `when condition`, then the `then condition` is never run. Failing the `when condition` is not considered a validation failure.

[Example rule table](https://github.com/ontodev/valve.py/blob/main/tests/resources/inputs/rule.tsv)

---

## Functions

VALVE functions are provided as values to the `condition` column in the field table or the `* condition` fields in the rule table.

When referencing the "target column", that is either the `column` from the field table, or the `then column` from the rule table.

There are five types of arguments passed to VALVE functions:
* **function**: another VALVE function
* **named argument**: some functions have optional args in the format `arg=value` (e.g., `direct=true` in [under](#under))
* **regex**: Perl-style regex pattern, always single-line (`s/pattern/[flags]` or `s/pattern/replacement/[flags]`)
* **table-column pair**: `table.column` or, when the column name has spaces, `table."column name"`
* **double-quoted string**: any other argument must be enclosed in double quotes - this includes table names and column names when they are not used together as a table-column pair (e.g., in [lookup](#lookup))

### CURIE

Usage: `CURIE(str-or-column, [str-or-column, ...])`

This function validates that the contents of the target column are all [CURIEs](https://www.w3.org/TR/curie/) and the prefix of each CURIE is present in the argument list. The `str-or-column` may be a double-quoted string (e.g., `CURIE("foo")`) or a `table.column` pair in which prefixes are defined (e.g., `CURIE(prefix.prefix)`). You may provide one or more arguments.

### distinct

Usage: `distinct(expr, [table.column, ...])`

This function validates that the contents of the target column are all distinct. If other `table.column` pairs (one or more) are provided after the `expr`, the values of the target column must also be distinct with all those values. The `expr` is either a datatype or another function to perform on the contents of the column.

### in

Usage: `in(str-or-column, [str-or-column, ...])`

This function validates that the contents of the target column are values present in the argument list. The `str-or-column` may be a double-quoted string (e.g., `in("a", "b", "c")`) or a `table.column` pair in which allowed values are defined (e.g., `in(external.Label)`). You may provide one or more arguments.

### list

Usage: `list("char", expr)`

This function splits the contents of the target column on the `char` (e.g, `|`) and then checks `expr` on each sub-value. The `expr` is either a datatype or another function to perform. If one sub-value fails the `expr` check, this function fails.

### lookup

Usage: `lookup("table", "column", "column2")`

This function should be used only in the `then condition` field of the rule table. This function takes the contents of the `when column` and searches for that value in `column`. If that value is found, then the `then column` value must be the corresponding value from `column2`.

Given the contents of the rule table:

| when table | when column | when condition | then table | then column | then condition | 
| ---------- | ----------- | -------------- | ---------- | ----------- | -------------- |
| exposure   | Material    | not blank      | exposure   | Material ID | lookup(external, Label, ID) |

... validates that when `exposure.Material` is not blank, the `exposure."Material ID"` in that same row is the `external.ID` in the same row as the `exposure.Material` value in `external.Label`:

*external*

| ID      | Label |
| ------- | ----- |
| FOO:123 | bar   |

*exposure*

| Material | Material ID |
| -------- | ----------- |
| bar      | FOO:123     |

### split

Usage: `split("char", count, expr1, expr2, [expr3, ...])`

This function splits the contents of the target column on the `"char"`. The number of sub-values must be equal to the `count` and the number of `exprs` provided after must also be equal to the `count`. Each `expr` is a datatype or function that is checked against the corresponding sub-value.

Given the contents of the field table:

| table | column | condition |
| ----- | ------ | --------- |
| foo   | bar    | split("&", 2, CURIE(prefix.prefix), in("a", "b", "c")) |

And given the value to check:

> FOO:123 & a

"FOO:123" will be validated against `CURIE(prefix.prefix)` and "a" will be validated against `in("a", "b", "c")`.

### sub

Usage: `sub(s/pattern/replacement/[flags], expr)`

This function uses regex substitution on the contents of the target column to replace `pattern` with `replacement`. You may include optional regex flags at the end of the pattern to dictate how the pattern should match. The following flags are currently supported:

* `a`: enable ASCII matching; `\w`, `\W`, `\b`, `\B`, `\d`, `\D`, `\s` and `\S` match only ASCII characters
* `g`: global match; if not includded, only replace the first match
* `i`: case-insensitive matching
* `x`: ignore non-escaped whitespace and treat any text after a non-escaped `#` as a comment

Once the value has been substituted, `expr` is run over the new value. This can be a datatype or a function.

Note that if you wish to use `/` in your regex pattern or substition, it must be escaped (`\/`).

### tree

Usage: `tree("column", [table2.column2])`

This function creates a tree structure using the contents of the target column as "parent" values and the contents of `column` (from the same target table) as "child" values. An optional `table2.column2` can be passed as long as `table2.column2` has already been defined as a tree. This means that the current tree will extend the `table2.column2` tree. All "parent" values are required to be in the "child" values, or in the extended tree (if provided).

The `tree` function may only be used as a `condition` in the field table. The tree name which can be referenced later in other `tree` functions and the `under` function is the `table` and `column` pair from the field table, e.g. this creates the tree `foo.bar` with child values form `foo.baz`:

| table | column | condition     |
| ----- | ------ | ------------- |
| foo   | bar    | tree(foo.baz) |

### under

Usage: `under(table.column, "top level", [direct=true])`

This function looks for all descendants of `"top level"` in a tree built from `table.column`. Please note that you must first define a `table.column` (corresponding to the `table` and `column` from the field table) tree using the `tree` function. If `direct=true` is included, only *direct* children of `"top level"` are considered allowed values.
