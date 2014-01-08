test:
	./node_modules/.bin/mocha \
	  --compilers coffee:coffee-script \
	  --reporter spec test.coffee \
	  --slow 1000
