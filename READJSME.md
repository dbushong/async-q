# Async.js for Q [![Build Status](https://travis-ci.org/dbushong/async-q.png?branch=master)](https://travis-ci.org/dbushong/async-q) [![Dependency Status](https://david-dm.org/dbushong/async-q.png?theme=shields.io)](https://david-dm.org/dbushong/async-q)

Promises with [Q](http://github.com/kriskowal/q) are awesome.  However,
there's a lot of existing code done using callback-oriented structures.
Much of this probably would have collapsed under its own weight long ago were
it not for the excellent [async.js](http://github.com/caolan/async).

A number of the functions provided by async.js, e.g. `parallel()` aren't
terribly useful to existing Q users, since you can just call `Q.all()`, but
I've included most of the functions for completeness.

All of the functions which return promises can also accept promises as any of
their arguments, for example instead of:

```js
fetchPages().then(function(pages) {
  return async.every(pages, isPageInDB);
}).then(function(ok) {
  return doStuff();
}).done();
```

You can just do:

```js
async.every(fetchPages(), isPageinDB).then(function(ok) {
  return doStuff();
}).done();
```

If I had to pick the most useful from this set, that are more annoying to
implement with vanilla Q, I'd say:

* [series](#series)
* [parallelLimit](#parallelLimit)
* [queue](#queue)
* [auto](#auto)

## Limitations

The only missing functions are internal utility routines like `iterator()`,
`apply()`, and `nextTick()`  If anyone misses those, let me know.

This code only works on node; I've not bothered to make it browser-safe in
any way.

You can also view the below examples [in CoffeeScript](README.md).

## Download

```
npm install async-q
```

## Usage

```js
var async;

async = require('async-q');
```

## Documentation


### Collections

* [each](#each)
* [eachSeries](#eachSeries)
* [eachLimit](#eachLimit)
* [map](#map)
* [mapSeries](#mapSeries)
* [mapLimit](#mapLimit)
* [filter](#filter)
* [filterSeries](#filterSeries)
* [reject](#reject)
* [rejectSeries](#rejectSeries)
* [reduce](#reduce)
* [reduceRight](#reduceRight)
* [detect](#detect)
* [detectSeries](#detectSeries)
* [sortBy](#sortBy)
* [some](#some)
* [every](#every)
* [concat](#concat)
* [concatSeries](#concatSeries)

### Control Flow

* [series](#series)
* [parallel](#parallel)
* [parallelLimit](#parallelLimit)
* [whilst](#whilst)
* [doWhilst](#doWhilst)
* [until](#until)
* [doUntil](#doUntil)
* [forever](#forever)
* [waterfall](#waterfall)
* [compose](#compose)
* [applyEach](#applyEach)
* [applyEachSeries](#applyEachSeries)
* [queue](#queue)
* [cargo](#cargo)
* [auto](#auto)
* [times](#times)
* [timesSeries](#timesSeries)

### Utils

* [memoize](#memoize)
* [unmemoize](#unmemoize)
* [log](#log)
* [dir](#dir)

## Collections

<a name="forEach" />
<a name="each" />
### each(arr, iterator)

Applies an iterator function to each item in an array, in parallel.
The iterator is called with an item from the list and returns a promise
for the result.  Returns a promise for an array of all of the results,
in the same order as the original array.

Note, that since this function applies the iterator to each item in parallel
there is no guarantee that the iterator functions will complete in order.

__Arguments__

* arr - An array to iterate over.
* iterator(item, index, arr) - A function to apply to each item in the array.
  The iterator must return a promise which will be resolved once it has
  completed.

__Example__

```js
/* assuming openFiles is an array of file names and saveFile is a function
    to save the modified contents of that file: */
async.each(openFiles, saveFile)["catch"](function(err) {
  // if any of the saves produced an error, err would equal that error
});
```

---------------------------------------

<a name="forEachSeries" />
<a name="eachSeries" />
### eachSeries(arr, iterator)

The same as `each`, only the iterator is applied to each item in the array in
series. The next iterator is only called once the current one has completed
processing. This means the iterator functions will complete in order.

---------------------------------------

<a name="forEachLimit" />
<a name="eachLimit" />
### eachLimit(arr, limit, iterator)

The same as `each` only no more than "limit" iterators will be simultaneously
running at any time.

Note that the items are not processed in batches, so there is no guarantee that
 the first "limit" iterator functions will complete before any others are
started.

__Arguments__

* arr - An array to iterate over.
* limit - The maximum number of iterators to run at any time.
* iterator(item, index, arr) - A function to apply to each item in the array.
  The iterator must return a promise for the result.

__Example__

```js
/* Assume documents is an array of JSON objects and requestApi is a
    function that interacts with a rate-limited REST api. */
async.eachLimit(documents, 20, requestApi)["catch"](function(err) {
  // if any of the saves produced an error, err would equal that error
});
```

---------------------------------------

<a name="map" />
### map(arr, iterator)

Produces a new array of values by mapping each value in the given array through
the iterator function. The iterator is called with an item from the array and
returns a promise for the result.

Note, that since this function applies the iterator to each item in parallel
there is no guarantee that the iterator functions will complete in order, however the promised results array returned will be in the same order as the original array.

(This function is actually just an alias for `each()`)

__Arguments__


* arr - An array to iterate over.
* iterator(item, index, arr) - A function to apply to each item in the array.
  The iterator must return a promise which will be resolved once it has
  completed.

__Example__

```js
var fs;

fs = require('q-io/fs');

async.map(['file1', 'file2', 'file3'], fs.stat).then(function(results) {
  // results is now an array of stats for each file
  return doStuff();
}).done();

// this is pretty much the same as:

Q.all(['file1', 'file2', 'file3'].map(fs.stat)).then(function(results) {
  // results is now an array of stats for each file
  return doStuff();
}).done();
```

---------------------------------------

<a name="mapSeries" />
### mapSeries(arr, iterator)

The same as map only the iterator is applied to each item in the array in
series. The next iterator is only called once the current one has completed
processing. The results array will be in the same order as the original.

(This function is actually just an alias for `eachSeries()`)

---------------------------------------

<a name="mapLimit" />
### mapLimit(arr, limit, iterator)

The same as map only no more than "limit" iterators will be simultaneously
running at any time.

Note that the items are not processed in batches, so there is no guarantee that
the first "limit" iterator functions will complete before any others are
started.

__Arguments__

* arr - An array to iterate over.
* limit - The maximum number of iterators to run at any time.
* iterator(item) - A function to apply to each item in the array.
  The iterator must return a promise for the result.

__Example__

```js
var fs;

fs = require('q-io/fs');

async.mapLimit(['file1', 'file2', 'file3'], 1, fs.stat).then(function(results) {
  // results is now an array of stats for each file
  return doStuff();
}).done();
```

---------------------------------------

<a name="filter" />
### filter(arr, iterator)

__Alias:__ select

Returns a promise for an array of all the values which pass an async truth test.
This operation is performed in parallel, but the results array will be in the
same order as the original.

__Arguments__

* arr - An array to iterate over.
* iterator(item) - A truth test to apply to each item in the array.
  The iterator must return a promise for a boolean.

__Example__

```js
var fs;

fs = require('q-io/fs');

async.filter(['file1', 'file2', 'file3'], fs.exists).then(function(results) {
  // results now equals an array of the existing files
  return doStuff();
}).done();
```

---------------------------------------

<a name="filterSeries" />
### filterSeries(arr, iterator)

__alias:__ selectSeries

The same as filter only the iterator is applied to each item in the array in
series. The next iterator is only called once the current one has completed
processing. The results array will be in the same order as the original.

---------------------------------------

<a name="reject" />
### reject(arr, iterator)

The opposite of filter. Removes values that pass an async truth test.

---------------------------------------

<a name="rejectSeries" />
### rejectSeries(arr, iterator)

The same as reject, only the iterator is applied to each item in the array
in series.


---------------------------------------

<a name="reduce" />
### reduce(arr, memo, iterator)

__aliases:__ inject, foldl

Reduces a list of values into a single value using an async iterator to return
each successive step. Memo is the initial state of the reduction. This
function only operates in series. For performance reasons, it may make sense to
split a call to this function into a parallel map, then use the normal
Array.prototype.reduce on the results. This function is for situations where
each step in the reduction needs to be async, if you can get the data before
reducing it then it's probably a good idea to do so.

Returns a promise for the reduction.

__Arguments__

* arr - An array to iterate over.
* memo - The initial state of the reduction.
* iterator(memo, item) - A function applied to each item in the
  array to produce the next step in the reduction. The iterator
  must return a promise for the state of the reduction.

__Example__

```js
async.reduce([1, 2, 3], 0, (function(memo, item) {
  return Q(memo + item);
})).then(function(result) {
  // result is now equal to the last value of memo, which is 6
  return doStuff();
}).done();
```

---------------------------------------

<a name="reduceRight" />
### reduceRight(arr, memo, iterator)

__Alias:__ foldr

Same as reduce, only operates on the items in the array in reverse order.


---------------------------------------

<a name="detect" />
### detect(arr, iterator)

Returns a promise for the first value in a list that passes an async truth test.
The iterator is applied in parallel, meaning the first iterator to return true
will resolve the promise with that result. That means the result might not be
the first item in the original array (in terms of order) that passes the test.

If order within the original array is important then look at detectSeries.

Note: the above is currently false; this function is currently just
`filter() + .get(0)`, but this should probably eventually change.

__Arguments__

* arr - An array to iterate over.
* iterator(item) - A truth test to apply to each item in the array.
  The iterator must return a promise for a boolean.

__Example__

```js
var fs;

fs = require('q-io/fs');

async.detect(['file1', 'file2', 'file3'], fs.exists).then(function(result) {
  // result now equals the first file in the list that exists
  return doStuff();
}).done();
```

---------------------------------------

<a name="detectSeries" />
### detectSeries(arr, iterator)

The same as detect, only the iterator is applied to each item in the array
in series. This means the result is always the first in the original array (in
terms of array order) that passes the truth test.

---------------------------------------

<a name="sortBy" />
### sortBy(arr, iterator)

Sorts a list by the results of running each value through an async iterator.
Returns a promise for a sorted array of the original values.

__Arguments__

* arr - An array to iterate over.
* iterator(item) - A function to apply to each item in the array.  The iterator
  must return a promise for a transformation of the item which is sortable.

__Example__

```js
var fs;

fs = require('q-io/fs');

async.sortBy(['file1', 'file2', 'file3'], function(file) {
  return fs.stat(file).get('mtime');
}).then(function(results) {
  // results is now the original array of files sorted by mod time
  return doStuff();
}).done();
```

---------------------------------------

<a name="some" />
### some(arr, iterator)

__Alias:__ any

Returns a promise for a boolean saying whether or not at least one element in
the array satisfies an async test.

Once any iterator call returns true, the main promise is immediately resolved.

That previous sentence is not yet true, but is aspirational.  This is currently
implemented as a test on whether `.filter()`'s `.length > 0`

__Arguments__

* arr - An array to iterate over.
* iterator(item) - A truth test to apply to each item in the array.
  The iterator must return a promise for a boolean.

__Example__

```js
var fs;

fs = require('q-io/fs');

async.some(['file1', 'file2', 'file3'], fs.exists).then(function(result) {
  // if result is true then at least one of the files exists
  return doStuff();
}).done();
```

---------------------------------------

<a name="every" />
### every(arr, iterator)

__Alias:__ all

Returns a promise for a boolean saying whether every element in the array
satisfies an async test.

__Arguments__

* arr - An array to iterate over.
* iterator(item) - A truth test to apply to each item in the array.
  The iterator must return a promise for a boolean.

__Example__

```js
async.every(['file1', 'file2', 'file3'], fs.exists).then(function(result) {
  // if result is true then every file exists
  return doStuff();
}).done();
```

---------------------------------------

<a name="concat" />
### concat(arr, iterator)

Applies an iterator to each item in a list, concatenating the results.
Returns a promise for the concatenated list. The iterators are called in
parallel, and the results are concatenated as they return. There is no
guarantee that the results array will be returned in the original order of the
arguments passed to the iterator function.

__Arguments__

* arr - An array to iterate over
* iterator(item) - A function to apply to each item in the array.
  The iterator must return a promise for an array of transformed results.

__Example__

```js
var fs;

fs = require('q-io/fs');

async.concat(['dir1', 'dir2', 'dir3'], fs.list).then(function(files) {
  // files is now a list of filenames that exist in the 3 dirs
  return doStuff();
}).done();
```

---------------------------------------

<a name="concatSeries" />
### concatSeries(arr, iterator)

Same as `async.concat`, but executes in series instead of parallel.

## Control Flow

<a name="series" />
### series(tasks)

Run an array of functions in series, each one running once the previous
function has completed.  Returns a promise for an array containing the
ordered results.

It is also possible to use an object instead of an array. Each property will be
run as a function and the results will be resolved as an object instead of an
array. This can be a more readable way of handling results from async.series.

__Arguments__

* tasks - An array or object containing functions to run, each function must
  return a promise for an optional result value.

__Example__

```js
async.series([
  function() {
    // do some stuff
    return Q('one');
  }, function() {
    // do some more stuff ...
    return Q('two');
  }
]).then(function(results) {
  // results is now equal to ['one', 'two']
  return doStuff();
}).done();

// an example using an object instead of an array

async.series({
  one: function() {
    return Q.delay(200).thenResolve(1);
  },
  two: function() {
    return Q.delay(100).thenResolve(2);
  }
}).then(function(results) {
  // results is now equal to: {one: 1, two: 2}
  return doStuff();
}).done();
```

---------------------------------------

<a name="parallel" />
### parallel(tasks)

Run an array of functions in parallel, without waiting until the previous
function has completed.  Returns a promise for an array of the results.

It is also possible to use an object instead of an array. Each property will be
run as a function and the promised results will be an object instead of an
array. This can be a more readable way of handling results from async.parallel.

Note: this isn't something you commonly want to do in Q-land; an array of
promises and `Q.all()` usually works just fine, but, you know, completeness and
all.

__Arguments__

* tasks - An array or object containing functions to run, each function
  should return a promise for an optional value.

__Example__

```js
async.parallel([
  function() {
    return Q.delay(200).thenResolve('one');
  }, function() {
    return Q.delay(100).thenResolve('two');
  }
]).then(function(results) {
  /* the results array will equal ['one','two'] even though
      the second function had a shorter timeout. */
  return doStuff();
}).done();

// an example using an object instead of an array

async.parallel({
  one: function() {
    return Q.delay(200).thenResolve(1);
  },
  two: function() {
    return Q.delay(100).thenResolve(2);
  }
}).then(function(results) {
  // results is now equals to: {one: 1, two: 2}
  return doStuff();
}).done();
```

---------------------------------------

<a name="parallelLimit" />
### parallelLimit(tasks, limit)

The same as parallel only the tasks are executed in parallel with a maximum of
"limit" tasks executing at any time.  Returns a promise for an array or object,
depending on which was passed.

Note that the tasks are not executed in batches, so there is no guarantee that
the first "limit" tasks will complete before any others are started.

__Arguments__

* tasks - An array or object containing functions to run, each function must
  return a promise for an optional result.
* limit - The maximum number of tasks to run at any time.

---------------------------------------

<a name="whilst" />
### whilst(test, fn)

Repeatedly call fn, while test returns true.  Returns promise that is fulfilled
when test fails.

__Arguments__

* test() - synchronous truth test to perform before each execution of fn.
* fn - A function to call each time the test passes. The function must return
  a promise that is fulfilled when it is done.

__Example__

```js
var count;

count = 0;

async.whilst((function() {
  return count < 5;
}), function() {
  count++;
  return Q.delay(1000);
}).then(function() {
  // 5 seconds have passed
  return doStuff();
}).done();
```

---------------------------------------

<a name="doWhilst" />
### doWhilst(fn, test)

The post check version of whilst. To reflect the difference in the order of
operations `test` and `fn` arguments are switched. `doWhilst` is to `whilst` as
`do while` is to `while` in plain JavaScript.

---------------------------------------

<a name="until" />
### until(test, fn)

Repeatedly call fn, until test returns true.

The inverse of async.whilst.

---------------------------------------

<a name="doUntil" />
### doUntil(fn, test)

Like doWhilst except the test is inverted. Note the argument ordering differs
from `until`.

---------------------------------------

<a name="forever" />
### forever(fn)

Calls the promise-returning function 'fn' repeatedly, in series, indefinitely.

---------------------------------------

<a name="waterfall" />
### waterfall(tasks)

Runs an array of functions in series, each passing their results to the next in
the array.  Returns a promise for the result of the final function.

Note: I'm not sure why you'd really want this in practice; you usually just
want to do: `foo().then((res1) -> ...).then((res2) -> ...)...`

__Arguments__

* tasks - An array of functions to run, each function must return a promise
  for a result that will be passed to the next function.

__Example__

```js
async.waterfall([
  function() {
    return Q(['one', 'two']);
  }, function(_arg) {
    var arg1, arg2;
    arg1 = _arg[0], arg2 = _arg[1];
    return Q('three');
  }, function(arg1) {
    // arg1 now equals 'three'
    return Q('done');
  }
]).then(function(result) {
  // result now equals 'done'
  return doStuff();
}).done();
```

---------------------------------------

<a name="compose" />
### compose(fn1, fn2...)

Creates a function which is a composition of the passed asynchronous
functions. Each function consumes the promised return value of the function that
follows. Composing functions f(), g() and h() would produce the result of
f(g(h())), only this version uses promises to obtain the return values.

Each function is executed with the `this` binding of the composed function.

__Arguments__

* functions... - the asynchronous functions to compose

__Example__

```js
var add1, add1mul3, mul3;

add1 = function(n) {
  return Q.delay(10).thenResolve(n + 1);
};

mul3 = function(n) {
  return Q.delay(10).thenResolve(n * 3);
};

add1mul3 = async.compose(mul3, add1);

add1mul3(4).then(function(result) {
  // result now equals 15
  return doStuff();
}).done();
```

---------------------------------------

<a name="applyEach" />
### applyEach(fns, args...)

Applies the provided arguments to each function in the array, resolving the
returned promise after all functions have completed.
If you only provide the first argument then it will return a function which
lets you pass in the arguments as if it were a single function call.

__Arguments__

* fns - the promise-returning functions to all call with the same arguments
* args... - any number of separate arguments to pass to the function

__Example__

```js
async.applyEach([enableSearch, updateSchema], 'bucket').done();

// partial application example:

async.each(buckets, async.applyEach([enableSearch, updateSchema])).done();
```

---------------------------------------

<a name="applyEachSeries" />
### applyEachSeries(arr, iterator)

The same as applyEach only the functions are applied in series.

---------------------------------------

<a name="queue" />
### queue(worker, concurrency)

Creates a queue object with the specified concurrency. Tasks added to the
queue will be processed in parallel (up to the concurrency limit). If all
workers are in progress, the task is queued until one is available. Once
a worker has completed a task, promise returned from its addition is resolved.

##### Arguments

* worker(task) - An promise-returning function for processing a queued
  task, which must resolve its promise when finished.
* concurrency - An integer for determining how many worker functions should be
  run in parallel.

##### Queue objects

The queue object returned by this function is an EventEmitter:

###### Functions

* length() - a function returning the number of items waiting to be processed.
* push(task) - add a new task to the queue and return a promise which is
  resolved once the worker has finished processing the task.  The promise
  object returned also contains a `start` property, which is a promise which
  is resolved when the task is started.
  Instead of a single task, an array of tasks can be submitted and an array
  of promises will be returned which can be individually handled or bundled
  with `Q.all()`
* unshift(task) - same as push but add a new task to the front of the queue.

###### Properties

* concurrency - an integer for determining how many worker functions should be
  run in parallel. This property can be changed after a queue is created to
  alter the concurrency on-the-fly.

###### Events

You may receive events with `queueObj.on 'foo', -> ...`

* saturated - emitted when the queue length hits the concurrency and further
  tasks will be queued
* empty - emitted when the last item from the queue is given to a worker
* drain - emitted when the last item from the queue has returned from the worker
          NOTE: actions contigent on the promise returned from the
          `push/unshift()` that queued the final task will not have finished
          when the drain event is fired; if you wish to run after that,
          do something like: `queueObj.on 'drain', -> process.nextTick -> ...`
          or use a `Q.all(...).then(...)` on those promises instead.

##### Example

```js
// create a queue object with concurrency 2
var q;

q = async.queue((function(_arg) {
  var name;
  name = _arg.name;
  return console.log("hello " + name);
}), 2);

// listen for an event

q.on('drain', function() {
  return console.log('all items have been processed');
});

// add some items to the queue

q.push({
  name: 'foo'
}).then(function() {
  return console.log('finished processing foo');
}).done();

q.push({
  name: 'bar'
}).then(function() {
  return console.log('finished processing bar');
}).done();

// add some items to the queue (batch-wise)

q.push([
  {
    name: 'baz'
  }, {
    name: 'bay'
  }, {
    name: 'bax'
  }
]).forEach(function(p) {
  return p.then(function() {
    return console.log('finished processing baz, bay, OR bax');
  }).done();
});

// add some items to the queue (batch-wise) and wait for all to finish

Q.all(q.push([
  {
    name: 'baz'
  }, {
    name: 'bay'
  }, {
    name: 'bax'
  }
])).then(function() {
  return console.log('finished processing baz, bay, AND bax');
}).done();

// add some items to the front of the queue

q.unshift({
  name: 'garply'
}).then(function() {
  return console.log('finished processing garply');
}).done();
```

##### Example using `.start` promise return from `push()`

```js
// if you didn't block on start, you'd create a huge array and die
var q;

q = async.queue((function(n) {
  return Q.delay(n * 10000).thenResolve(n);
}), 10);

// imagine this is an async line-reader.eachLine() call or something

async.whilst((function() {
  return true;
}), function() {
  // print the result once task is done
  var res;
  (res = q.push(Math.random())).then(function(n) {
    return console.log("waited " + n + "ms");
  });
  // only continue the loop when the task is started
  return res.start;
});
```


---------------------------------------

<a name="cargo" />
### cargo(worker, [payload])

Creates a cargo object with the specified payload. Tasks added to the
cargo will be processed altogether (up to the payload limit). If the
worker is in progress, the task is queued until it is available. Once
the worker has completed some tasks, all of the promises returned from calls
to push will be resolved.

##### Arguments

* worker(tasks) - A promise-returning function for processing an array of
  queued tasks.
* payload - An optional integer for determining how many tasks should be
  processed per round; if omitted, the default is unlimited.

##### Cargo objects

The cargo object returned by this function is an EventEmitter:

###### Functions

* length() - a function returning the number of items waiting to be processed.
* push(task) - add a new task to the queue, returns a promise that is resolved
  once the worker has finished processing the task.
  Instead of a single task, an array of tasks can be submitted in which case
  an array of promises will be returned.

###### Properties

* payload - an integer for determining how many tasks should be
  process per round. This property can be changed after a cargo is created to
  alter the payload on-the-fly.

###### Events

You may receive events with `cargoObj.on 'foo', -> ...`

* saturated - emitted when the queue length hits the payload and further
  tasks will be queued
* empty - emitted when the last item from the queue is given to a worker
* drain - emitted when the last item from the queue has returned from the worker
          NOTE: actions contigent on the promise returned from the
          `push()` that queued the final task will not have finished
          when the drain event is fired; if you wish to run after that,
          do something like: `cargoObj.on 'drain', -> process.nextTick -> ...`
          or use a `Q.all(...).then(...)` on those promises instead.

##### Example

```js
// create a cargo object with payload 2
var cargo;

cargo = async.cargo(function(tasks) {
  var name, _i, _len, _results;
  _results = [];
  for (_i = 0, _len = tasks.length; _i < _len; _i++) {
    name = tasks[_i].name;
    _results.push(console.log("hello " + name));
  }
  return _results;
}, 2);

// add some items

cargo.push({
  name: 'foo'
}).then(function() {
  return console.log('finished processing foo');
}).done();

cargo.push({
  name: 'bar'
}).then(function() {
  return console.log('finished processing bar');
}).done();

cargo.push({
  name: 'baz'
}).then(function() {
  return console.log('finished processing baz');
}).done();
```

---------------------------------------

<a name="auto" />
### auto(tasks)

Determines the best order for running functions based on their requirements.
Each function can optionally depend on other functions being completed first,
and each function is run as soon as its requirements are satisfied.
Functions receive an object containing the results of functions which have
completed so far.  Returns a promise for the final version of the results
object.

__Arguments__

* tasks - An object literal containing named functions or an array of
  requirements, with the function itself the last item in the array. The key
  used for each function or array is used when specifying requirements. The
  function receives a results object, containing the results of
  the previously executed functions, keyed by their name.

__Example__

```js
async.auto({
  get_data: function() {
    // async code to get some data
  },
  make_folder: function() {
    /* async code to create a directory to store a file in
        this is run at the same time as getting the data */
  },
  write_file: [
    'get_data', 'make_folder', function() {
      /* once there is some data and the directory exists,
          write the data to a file in the directory */
      return filename;
    }
  ],
  email_link: [
    'write_file', function(results) {
      /* once the file is written let's email a link to it...
          results.write_file contains the filename returned by write_file. */
    }
  ]
}).done();
```

This is a fairly trivial example, but to do this using the basic parallel and
series functions would look like this:

```js
async.parallel([
  function() {
    // async code to get some data
  }, function() {
    /* async code to create a directory to store a file in
        this is run at the same time as getting the data */
  }
]).then(function() {
  return async.waterfall([
    function() {
      /* once there is some data and the directory exists,
          write the data to a file in the directory */
      return filename;
    }, function(results) {
      // once the file is written let's email a link to it...
    }
  ]);
}).done();
```

For a complicated series of async tasks using the auto function makes adding
new tasks much easier and makes the code more readable.

---------------------------------------

<a name="times" />
### times(n, fn)

Calls the fn n times and accumulates results in the same manner
you would use with async.map.

__Arguments__

* n - The number of times to run the function.
* fn(i) - The promise-returning function to call n times, passed i <- 0...n

__Example__

```js
// Pretend this is some complicated async factory
var createUser;

createUser = function(id) {
  return Q({
    id: "user" + id
  });
};

// generate 5 users

async.times(5, createUser).then(function(users) {
  // we should now have 5 users
  return doStuff();
}).done();
```

---------------------------------------

<a name="timesSeries" />
### timesSeries(n, fn)

The same as times only the iterator is applied to each item in the array in
series. The next iterator is only called once the current one has completed
processing. The results array will be in the same order as the original.

## Utils

<a name="memoize" />
### memoize(fn, [hasher])

Caches the results of an async function. When creating a hash to store function
results against an optional hash function can be used.

The cache of results is exposed as the `memo` property of the function returned
by `memoize`.

__Arguments__

* fn - the function you to proxy and cache results from.
* hasher - an optional function for generating a custom hash for storing
  results, it has all the arguments applied to it apart from the callback, and
  must be synchronous.

__Example__

```js
var fn, slow_fn;

slow_fn = function(name) {
  // do something
  return Q(result);
};

fn = async.memoize(slow_fn);

// fn can now be used as if it were slow_fn

fn('some name').then(function() {
  return doStuff();
}).done();
```

---------------------------------------

<a name="unmemoize" />
### unmemoize(fn)

Undoes a memoized function, returning the original, unmemoized form. Comes
in handy in tests.

__Arguments__

* fn - the memoized function

---------------------------------------

<a name="log" />
### log(function, arguments...)

Logs the result of an async function to the console. Only works in node.js or
in browsers that support console.log and console.error (such as FF and Chrome).
Returns a promise for further chaining.

__Arguments__

* function - The function you want to eventually apply all arguments to.
* arguments... - Any number of arguments to apply to the function.

__Example__

```js
var hello;

hello = function(name) {
  return Q.delay(1000).thenResolve("hello " + name);
};
```

```
coffee> async.log hello, 'world'
[object Object]
hello world
```

---------------------------------------

<a name="dir" />
### dir(function, arguments...)

The same as `async.log` except it calls `console.dir()` instead
of `console.log()`
