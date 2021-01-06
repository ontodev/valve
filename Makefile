# npm install nearley csv-parse
# export PATH=$(npm bin):$PATH 

SHELL := /bin/bash

test: python-test js-test

build build/distinct:
	mkdir -p $@

########## PYTHON TESTS ##########

# venv for testing locally

.PHONY: _venv
_venv:
	python3 -m venv _venv

build/valve.py/: | build
	cd build && git clone https://github.com/ontodev/valve.py.git

python-setup: _venv build/valve.py
	source _venv/bin/activate
	cd $(word 2,$^) && pip install .

# test steps

build/python-errors.tsv: tests/inputs | build
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

# nodeenv for testing locally

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

# test steps

build/node-errors.tsv: tests/inputs | build
	valve-js $< -o $@ || true

build/node-errors-distinct.tsv: tests/inputs | build/distinct
	valve-js $< -d build/distinct -o $@ || true

node-diff: tests/compare.py tests/errors.tsv build/node-errors.tsv
	python3 $^

node-diff-distinct: tests/compare.py tests/errors-distinct.tsv build/node-errors-distinct.tsv
	python3 $^

node-test:
	make node-diff
	make node-diff-distinct

