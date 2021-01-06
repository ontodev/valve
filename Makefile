# npm install nearley csv-parse
# export PATH=$(npm bin):$PATH 

SHELL := /bin/bash

test: python-test js-test

build build/distinct:
	mkdir -p $@

########## PYTHON TESTS ##########

# venv for testing manually

.PHONY: _venv
_venv:
	python3 -m venv _venv

build/valve.py/: | build
	cd build && git clone https://github.com/ontodev/valve.py.git

python-setup: _venv build/valve.py
	source _venv/bin/activate
	cd $(word 2,$^) && pip install .

# test steps

build/python-errors.tsv: tests/inputs
	valve $< -o $@ || true

build/python-errors-distinct.tsv: tests/inputs | build/distinct
	valve $< -d build/distinct -o $@ || true

python-diff: tests/compare.py tests/errors.tsv build/python-errors.tsv
	python3 $^

python-diff-distinct: tests/compare.py tests/errors-distinct.tsv build/python-errors-distinct.tsv
	python3 $^

python-test:
	make python-diff
	make python-diff-distinct

########## JAVASCRIPT TESTS ##########

# TODO - revert to master once port is merged
build/valve.js/: | build
	cd build && \
	git clone https://github.com/ontodev/valve.js.git && \
	cd valve.js && \
	git checkout port

_nodeenv: _venv
	pip install nodeenv
	nodeenv _nodeenv || true

node-setup: _nodeenv build/valve.js
	source _nodeenv/bin/activate
	cd $(word 2,$^) && npm i .

build/js-errors.tsv: tests/inputs
	valve-js $< -o $@ || true

build/js-errors-distinct.tsv: tests/inputs | build/distinct
	valve-js $< -d build/distinct -o $@ || true

js-diff: tests/compare.py tests/errors.tsv build/js-errors.tsv
	python3 $^

js-diff-distinct: tests/compare.py tests/errors-distinct.tsv build/js-errors-distinct.tsv
	python3 $^

js-test:
	make node-setup
	make js-diff
	make js-diff-distinct

