build:
	mkdir -p $@

build/valve_grammar.ne: | build
	curl -Lk https://raw.githubusercontent.com/ontodev/valve.js/main/valve_grammar.ne > $@

build/nearley: | build
	cd build && git clone https://github.com/Hardmath123/nearley

build/valve_grammar.py: build/valve_grammar.ne | build/nearley
	python3 -m lark.tools.nearley $< expression $| --es6 > $@

# Generate grammar, then ...
# 1. Remove init babel from first line
# 2. Encase grammar in triple quotes to allow for line breaks
# 3. Replace literal '\n' with line breaks
# 4. Fix extra escaping
# 5. Fix extra escaping on single quotes
# 6. Add escaping for double quotes (double quotes must be escaped within double quoted text)
# 7. Fix empty escaping (Lark will yell at you for \\)
# 8. Add x flag to regex using '\n'
# 9. Format using black
build/parse.py: build/valve_grammar.py
	tail -n +2 $< | \
	perl -pe "s/grammar = (.+)/grammar = ''\1''/g" | \
	perl -pe 's/(?<!\\)\\n/\n/gx' | \
	perl -pe 's/\\\\/\\/gx' | \
	perl -pe "s/\\\'/'/g" | \
	perl -pe 's/"\\\"/"\\\\"/g' | \
	perl -pe 's/"\\\\"$$/"\\\\\\\\"/g' | \
	perl -pe 's/(\/\[.*\\n.*]\/)/\1x/g'> $@
	black --line-length 100 $@
