export NPM_CONFIG_REGISTRY=http://registry.npmjs.org
BIN=./node_modules/.bin

.PHONY: test publish

default: READJSME.md index.js

READJSME.md: README.md js-md.coffee $(BIN)/coffee
	$(BIN)/coffee js-md.coffee $< > $@.tmp \
	  && mv -f $@.tmp $@ \
	  || (rm -f $@.tmp && false)

$(BIN)/%:
	npm install

test: $(BIN)/mocha index.js
	$(BIN)/mocha \
	  --compilers coffee:coffee-script/register \
	  --reporter spec test.coffee \
	  --slow 1000

index.js: async.coffee $(BIN)/coffee
	./node_modules/.bin/coffee -bcps < $< > $@.tmp \
	  && mv -f $@.tmp $@ \
	  || (rm -f $@.tmp && false)

publish: test
	npm publish
