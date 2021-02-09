# VALVE is A Lightweight Validation Engine

* [Command Line Usage](#command-line-usage)
    * [Configuration Files](#configuration-files)
    * [Functions](#functions)
    * [Other Options](#other-options)
* [API](#api)

This repository will contain documentation and tests common to different VAVLE implementations.
So far we're working on:

- [valve.py](https://github.com/ontodev/valve.py)
- [valve.js](https://github.com/ontodev/valve.js)

## Command Line Usage

Note that if you are using the JS version of VALVE, the command name will be `valve-js`. If you are using the Python version, it is just `valve`.

```
valve path [path ...] [-d DISTINCT] [-r ROW_START] -o OUTPUT
```

Each `path` may be a file or a directory. If a directory is passed, VALVE will search for all TSVs and CSVs within that directory and add them to the list of input files. It will not search nested directories.

At this time, only TSV and CSV tables are accepted.

The output `-o`/`--output` must be a path to a TSV or CSV file to write validation messages to. The output is formatted based on [COGS message tables](https://github.com/ontodev/cogs#message-tables). An example table can be found [here](https://github.com/ontodev/valve.py/blob/main/tests/resources/errors.tsv).

## Configuration Files

Two VALVE configuration files (as TSV or CSV) are required:
* `datatype`
* `field`

You may also include an optional `rule` table.

These can be passed as individual files to the input, or you can pass a directory containing these files. We list the required and optional headers below, but you are welcome to include any other headers you find helpful (e.g., `note`). These will be ignored by VALVE.

### Datatype Table

Datatypes allow you to define regex patterns for cell values. The datatypes are a hierarchy of types, and when a datatype is provided as a `condition`, all parent values are also checked.

The datatype table can have the following fields (a `*` indicates that it is a required columns):
* `datatype` \*: name of datatype - a single word that uses any alphanumeric character or `-` and `_`
* `parent` \*: parent datatype - must exist in the `datatype` column
* `match`\*: regex match (this column is required but blank cells are allowed)
* `level` \*: validation fail level when a value does not meet the regex match (info, warn, or error)
* `message`: an [error message](#error-messages)
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
* `message`: an [error message](#error-messages)

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
* `message`: an [error message](#error-messages)

If the contents of the `"when table"."when column"` do not pass the `when condition`, then the `then condition` is never run. Failing the `when condition` is not considered a validation failure.

[Example rule table](https://github.com/ontodev/valve.py/blob/main/tests/resources/inputs/rule.tsv)


### Error Messages

In each of the configuration tables, you may include the optional `message` column to replace the default error message. Within this message, you can use variables that will be replaced in the output message:
* `{value}`: the failing value (i.e., if you are using `list`, it will be the value in the list that failed, not the full list)
* `{table}`: the table name containing the violation
* `{column}`: the column name containing the violation
* `{row_idx}`: the row number containing the violation
* `{condition}`: the condition that failed

For example:
> '{value}' at {table}:{column} row {row_idx} failed {condition}

Keep in mind that you can use as many or as few variables as you want; not all are required in the message.

---

## Functions

VALVE functions are provided as values to the `condition` column in the field table or the `* condition` fields in the rule table.

When referencing the "target column", that is either the `column` from the field table, or the `then column` from the rule table.

There are five types of arguments passed to VALVE functions:
* **function**: another VALVE function
* **named argument**: some functions have optional args in the format `arg=value` (e.g., `direct=true` in [under](#under)) - if the value has a space or other non-alphanumeric characters, it should be enclosed in double quotes
* **regex**: Perl-style regex pattern, always single-line (`/pattern/[flags]` for matching or `s/pattern/replacement/[flags]` for substitution)
* **table-column pair**: `table.column` or, when the column name has spaces, `table."column name"`
* **string**: any other argument is a basic string - any string with spaces or other non-alphanumeric characters must be enclosed in double quotes

### any

Usage: `any(expr, expr, [expr, ...])`

This function validates that the contents of the target column meet at least one of the conditions provided in the arguments of `any`. The `expr` is either a datatype or another function.

### concat

Usage: `concat(str-or-expr, str-or-expr, [str-or-expr, ...])`

This function validates the given expressions (datatypes or functions) based on their place within the function. If a string is provided and it is not a datatype label, this will be evaluated as a literal that matches a substring within the value of the target column. Any contents between literals will be evaluated by the expression between them. Whitespace is important, so make sure to include it in the literals.

For example, take the target value:
> foo | bar & baz

And the function:
```
concat(label, " | ", in(table.column), " & ", under(table.column))
```

The value 'foo' is validated as a `label` datatype, 'bar' is validated by the `in` function, and 'baz' is validated by the `under` function. The pipe and ampersand are not validated, but they are used to determine the values to validate.

If a string literal is not found in the target value, the function will return an error.

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

Usage: `lookup(table, column, column2)`

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

### not

Usage: `not(expr)`

This function validates that the contents of the target column *do not* match the provided expression. The expression is either a datatype or another function.

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

Usage: `tree(column, [table2.column2])`

This function creates a tree structure using the contents of the target column as "parent" values and the contents of `column` (from the same target table) as "child" values. An optional `table2.column2` can be passed as long as `table2.column2` has already been defined as a tree. This means that the current tree will extend the `table2.column2` tree. All "parent" values are required to be in the "child" values, or in the extended tree (if provided).

The `tree` function may only be used as a `condition` in the field table. The tree name which can be referenced later in other `tree` functions and the `under` function is the `table` and `column` pair from the field table, e.g. this creates the tree `foo.bar` with child values form `foo.baz`:

| table | column | condition     |
| ----- | ------ | ------------- |
| foo   | bar    | tree(foo.baz) |

### under

Usage: `under(table.column, "top level", [direct=true])`

This function looks for all descendants of `"top level"` in a tree built from `table.column`. Please note that you must first define a `table.column` (corresponding to the `table` and `column` from the field table) tree using the `tree` function. If `direct=true` is included, only *direct* children of `"top level"` are considered allowed values.

---

### Other Options

#### Distinct Messages

Often, the same validation problem is found duplicated on multiple rows. It may be beneficial to just see only the *first* instance of any unique message. The `-d`/`--distinct` option collects distinct messages and writes *only* the input rows that correspond to these messages to a new `*_distinct` file in the provided directory:
```
valve input/ -d distinct/ -o problems_distinct.tsv
```

For example, if multiple problems are found in `input/table.tsv`, the first row with the message will be written to `distinct/table_distinct.tsv`. The cell locations in the output (`problems_distinct.tsv`) correspond to the cells in `distinct/table_distinct.tsv`, not the original input.

#### Row Start

By default, VALVE begins validation on row 2 of all input files. The first row must always be the headers, but if you wish to skip N number of rows, you can do so with `-r`/`--row-start`:
```
valve input/ -r 3 -o problems.tsv
```

This tells VALVE to begin validation on row 3 of all input files, excluding the VALVE configuration files.

---

## API

You can import the VALVE module into your Python projects:
```python
import valve
```

... or your Node projects:
```javascript
const valve = require("valve-js");
```

<!-- TODO: add link to auto-generated docs -->
The main method is `valve.validate` ([py](https://github.com/ontodev/valve.py/blob/main/valve/valve.py#L1470), [js]()), which accepts either a list of input paths (files or directories) along with some optional parameters:
* `distinct_messages`/`distinctMessages`: a path to a directory to place distinct messages, or null if you do not want distinct outputs (default: `None`/`null`)
* `row_start`/`rowStart`: the row number to start validating input tables on (default: `2`)
* `add_functions`/`addFunctions`: an object containing additional custom functions (default: `None`/`null`)

`valve.validate` returns a list of messages. Each message is a dictionary with fields for [COGS message tables](https://github.com/ontodev/cogs#message-tables).

### Custom Functions

You may call `valve.validate` with an optional `functions={...}`/`addFunctions` argument. The dictionary value should be in the format of function name (for use in rule and field tables) -> details dict. The details dict includes the following items:
* `usage`: usage text (optional)
* `validate`: the function to run for VALVE validation
* `check`: the [expected structure](#checking-with-a-list) of the arguments OR a custom [check function](#checking-with-a-function)

The function name should not collide with any [builtin functions](https://github.com/ontodev/valve/blob/main/README.md#functions). The function must be defined in your file with the following required parameters in this order, even if they are not all used:

1. `config`: VALVE configuration dictionary
2. `args`: parsed (via `valve.parse(str)`) arguments from the function
3. `table`: table name containing value
4. `column`: column name containing value
5. `row_idx`/`rowIdx`: row index containing value
6. `value`: value to run the function on

The function should return a list of messages (empty on success). The messages are dictionaries with the following keys:
* `table`: table name (no parent directories or extension)
* `cell`: A1 format of cell location - you can use `valve.idx_to_a1` (py) or `valve.idxToA1` (js) to get this\*
* `message`: detailed error message

\* When getting the A1 format of the location, note that the `row_idx`/`rowIdx` always starts at zero, without headers (or any skipped rows) included in the list of rows. You must add `row_start`/`rowStart` to this to get the correct row number.

You may also include a `suggestion` key if you want to provide a suggested replacement value.

You can use `valve.error` to format the error message as shown below.

For example in Python:
```python
def validate_foo(config, args, table, column, row_idx, value):
    required_in_value = args[0]["value"]
    if required_in_value not in value:
        row_start = config["row_start"]
        col_idx = config["table_details"][table]["fields"].index(column)
        cell_loc = valve.idx_to_a1(row_idx + row_start, col_idx + 1)
        message = f"'{value}' must contain '{required_in_value}'"
        return [valve.error(config, table, column, rowIdx, message)]
    return []

valve.validate(
    "inputs/",
    functions={
        "foo": {
            "usage": "foo(string)",
            "check": ["string"],
            "validate": validate_foo
        }
    }
)
```

... and in JavaScript:
```javascript
function validateFoo(config, args, table, column, rowIdx, value) {
    let requiredInValue = args[0].value;
    if (!value.includes(requiredInValue)) {
        let rowStart = config.rowStart;
        let colIdx = config.tableDetails[table].fields.indexOf(column);
        let cellLoc = valve.idxToA1(rowIdx + rowStart, colIdx + 1);
        let message = `${value}' must contain '${required_in_value}`;
        return [error(config, table, column, rowIdx, message)];
    }
    return [];
}

valve.validate("inputs/", null, 2, {
  foo: { usage: "foo(string)", check: ["string"], validate: validateFoo },
});
```

#### Checking with a list

The `check` list outlines what the arguments passed in should look like. The example above uses a list to validate that exactly one string is passed to `foo`. Each element in the list is an argument type:
* `column`: a column in the target table (the `table` column of the rule or field table)
* `expression`: function or datatype
* `field`: a table-column pair where the table is in the inputs and the column is in the table
* `named:...`: named argument followed by the argument key (e.g., if your named arg looks like `distinct=true`, then this value will be `named:distinct`)
* `regex_match`: a regex pattern
* `regex_sub`: a regex substitution
* `string`: any other string
* `tree`: a defined treename (table-column pair)

If an argument can be of multiple types, you can join them with ` or `. For example, for an argument that can be either a string or a field: `string or field`.

Optional and multi-arity arguments can be specified with special modifiers attached to the end:
* `*`: zero or more
* `?`: zero or one
* `+`: one or more

For example, if you expect one or more string arguments: `string*`. Named arguments are almost always optional, so these would look like: `named:distinct?`. Optional or multi-arity arguments should always be the last parameters.

#### Checking with a function

Lists do not allow you to check dependencies between arguments, so it may be beneficial to define your own `check` function. This function must have four parameters (but not all need to be used):
* `config`: VALVE configuration dictionary
* `table`: the target table that the function will be run in
* `column`: the target column that the function will be run in
* `args`: a list of parsed args passed to the function

The function should return a string error message if any error was found, otherwise, it should return `None`. The custom functions are useful for when you want to validate more than just the structure, for example, if you expect two values that are tables other than the target table.

For example in Python:
```python
def validate_foo(config, args, table, column, row_idx, value):
    ...

def check_foo(config, table, column, args):
    i = 1
    for a in args:
        if i == 2:
            return f"foo expects 2 arguments, but {len(args)} were given"
        if a["type"] != "string":
            return f"foo argument {i} must be a string representing a table"
        if a["value"] == table:
            return f"foo argument {i} must not be '{table}'"
        if a["value"] not in config["table_details"]:
            return f"foo argument {i} must be a table in inputs other than '{table}'"
        i += 1

valve.validate(
    "inputs/",
    functions={
        "foo": {
            "usage": "foo(string, string)",
            "check": check_foo,
            "validate": validate_foo
        }
    }
)
```

... and in JavaScript:
```javascript
function validateFoo(config, args, table, column, rowIdx, value) {
	...
}

function checkFoo(config, table, column, args) {
    let i = 1;
    for (let a of args) {
        if (i === 2) {
            return `foo expects 2 arguments, but ${args.length} were given`;
        }
        if (a.type !== "string") {
            return `foo argument ${i} must be a string representing a table`;
        }
        if (a.value === table) {
            return `foo argument ${i} must not be '${table}'`;
        }
        if (config.tableDetails.indexOf(a.value) < 0) {
        	return `foo argument ${i} must be a table in inputs other than '${table}'`;
        }
        i++;
    }
}

valve.validate("inputs/", null, 2, {
  foo: { usage: "foo(string, string)", check: checkFoo, validate: validateFoo },
});
```
