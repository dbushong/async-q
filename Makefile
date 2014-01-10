BIN=./node_modules/.bin

.PHONY: test publish

$(BIN)/%:
	npm install

test: $(BIN)/mocha
	$(BIN)/mocha \
	  --compilers coffee:coffee-script \
	  --reporter spec test.coffee \
	  --slow 1000

index.js: async.coffee $(BIN)/coffee
	./node_modules/.bin/coffee -bcps < $< > $@

publish: test
	npm publish
