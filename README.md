# Async.js for Q

Promises with [Q](http://github.com/kriskowal/q) are awesome.  However,
there's a lot of existing code done using callback-oriented structures.
Much of this probably would have collapsed under its own weight long ago were
it not for the excellent [async.js](http://github.com/caolan/async).

A number of the functions provided by async.js, e.g. `parallel()` aren't
terribly useful to existing Q users, since you can just call `Q.all()`, but
I've included most of the functions for completeness.

If I had to pick the most useful from this set, that are more annoying to 
implement with vanilla Q, I'd say:

* [series](#series)
* [parallelLimit](#parallelLimit)
* [queue](#queue)
* [auto](#auto)

## Limitations

The only missing functions are, at the moment `cargo()` and a few of the
internal utility routines like `iterator()`, `apply()`, and `nextTick()`
If anyone missed those, let me know.

This code only works on Node; I've not bothered to make it browser-safe in
any way.

It currently needs `Q.try()` wrapping around a lot of things; I'll get to that
RSN.

All of the below examples are in CoffeeScript because I like it.

## Usage

```coffee
async = require 'q-async'
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
* [parallelLimit](#parallellimittasks-limit-callback)
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
* iterator(item) - A function to apply to each item in the array.
  The iterator must return a promise which will be resolved once it has
  completed.

__Example__

```coffee
# assuming openFiles is an array of file names and saveFile is a function
# to save the modified contents of that file:

async.each(openFiles, saveFile).catch (err) ->
  # if any of the saves produced an error, err would equal that error
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
* iterator(item) - A function to apply to each item in the array.
  The iterator must return a promise for the result.

__Example__

```coffee
# Assume documents is an array of JSON objects and requestApi is a
# function that interacts with a rate-limited REST api.

async.eachLimit(documents, 20, requestApi).catch (err) ->
  # if any of the saves produced an error, err would equal that error
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
* iterator(item) - A function to apply to each item in the array.
  The iterator must return a promise which will be resolved once it has
  completed.

__Example__

```coffee
fs = require 'q-io/fs'
async.map(['file1','file2','file3'], fs.stat)
  .then (results) ->
    # results is now an array of stats for each file
  .done()

# this is pretty much the same as:

['file1','file2','file3'].map(fs.stat).all()
  .then (results) ->
    # results is now an array of stats for each file
  .done()
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

```coffee
fs = require 'q-io/fs'
async.mapLimit(['file1','file2','file3'], 1, fs.stat)
  .then (results) ->
    # results is now an array of stats for each file
  .done()
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

```coffee
fs = require 'q-io/fs'
async.filter(['file1','file2','file3'], fs.exists)
  .then (results) ->
    # results now equals an array of the existing files
  .done()
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

```coffee
async.reduce([1,2,3], 0, ((memo, item) -> Q(memo + item)))
  .then (result) ->
    # result is now equal to the last value of memo, which is 6
  .done()
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

Note: the above is currently false; this function is currently just `filter()`
+ `.get(0)`, but this should probably eventually change.

__Arguments__

* arr - An array to iterate over.
* iterator(item) - A truth test to apply to each item in the array.
  The iterator must return a promise for a boolean.

__Example__

```coffee
fs = require 'q-io/fs'
async.detect(['file1','file2','file3'], fs.exists)
  .then (result) ->
    # result now equals the first file in the list that exists
  .done()
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

```coffee
fs = require 'q-io/fs'
async.sortBy(['file1','file2','file3'], (file) -> fs.stat(file).get('mtime'))
  .then (results) ->
    # results is now the original array of files sorted by
    # modified date
  .done()
```

---------------------------------------

<a name="some" />
### some(arr, iterator)

__Alias:__ any

Returns a promise for a boolean saying whether or not at least one element in
the array satisfies an async test.

Once any iterator call returns true, the main callback is immediately called.

That previous sentence is not yet true, but is aspirational.  This is currently
implemented as a test on whether `.filter()`'s `.length > 0`

__Arguments__

* arr - An array to iterate over.
* iterator(item) - A truth test to apply to each item in the array.
  The iterator must return a promise for a boolean.

__Example__

```coffee
fs = require 'q-io/fs'
async.some(['file1','file2','file3'], fs.exists)
  .then (result) ->
    # if result is true then at least one of the files exists
  .done()
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

```coffee
async.every(['file1','file2','file3'], fs.exists)
  .then (result) ->
    # if result is true then every file exists
  .done()
```

---------------------------------------

<a name="concat" />
### concat(arr, iterator)

Applies an iterator to each item in a list, concatenating the results.
Returns a promise for the concatenated list. The iterators are called in
parallel, and the results are concatenated as they return. There is no
guarantee that the results array will be returned in the original order of the
arguments passed to the iterator function.

That last sentence is a lie; this is currently implemented as `map()` + 
concatenation of the results.

__Arguments__

* arr - An array to iterate over
* iterator(item) - A function to apply to each item in the array.
  The iterator must return a promise for an array of transformed results.

__Example__

```coffee
fs = require 'q-io/fs'
async.concat(['dir1','dir2','dir3'], fs.list)
  .then (files) ->
    # files is now a list of filenames that exist in the 3 directories
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
run as a function and the results will be passed to the final callback as an
object instead of an array. This can be a more readable way of handling results
from async.series.

__Arguments__

* tasks - An array or object containing functions to run, each function must
  return a promise for an optional result value.

__Example__

```coffee
async.series([
  ->
    # do some stuff
    Q 'one'
  ->
    # do some more stuff ...
    Q 'two'
]).then (results) ->
    # results is now equal to ['one', 'two']
  .done()

// an example using an object instead of an array
async.series({
  one: -> Q.delay(200).thenResolve(1)
  two: -> Q.delay(100).thenResolve(2)
}).then (results) ->
    # results is now equal to: {one: 1, two: 2}
  .done()
```
