async = require './'
Q     = require 'q'

require('mocha-as-promised')()
chai = require 'chai'
chai.use require 'chai-as-promised'
{ assert: { strictEqual: equal, deepEqual, isRejected, fail, becomes } } = chai

eachIterator = (args, x) -> Q.delay(x*25).then -> args.push x

mapIterator = (call_order, x) ->
  Q.delay(x*25).then ->
    call_order.push x
    x*2

filterIterator = (x) -> Q.delay(x*25).thenResolve x % 2

detectIterator = (call_order, x) ->
  Q.delay(x*25).then ->
    call_order.push x
    x is 2

eachNoCallbackIterator = (x) ->
  equal x, 1
  Q()

getFunctionsObject = (call_order) ->
  one: -> Q.delay(125).then ->
    call_order.push 1
    1
  two: -> Q.delay(200).then ->
    call_order.push 2
    2
  three: -> Q.delay(50).then ->
    call_order.push 3
    [3, 3]

getFunctionsArray = (call_order) ->
  [
    -> Q.delay(50).then ->
      call_order.push 1
      1
    -> Q.delay(100).then ->
      call_order.push 2
      2
    -> Q.delay(25).then ->
      call_order.push 3
      [3, 3]
  ]

describe 'forever()', ->
  it "runs until it doesn't", ->
    counter = 0
    isRejected async.forever(->
      throw 'too big!' if ++counter is 50
      Q(counter)
    ), /^too big!$/

applyOneTwoThree = (call_order) ->
  [
    (val) ->
      equal val, 5
      Q.delay(100).then ->
        call_order.push 'one'
        1
    (val) ->
      equal val, 5
      Q.delay(50).then ->
        call_order.push 'two'
        2
    (val) ->
      equal val, 5
      Q.delay(150).then ->
        call_order.push 'three'
        3
  ]

describe 'applyEach()', ->
  it 'immediately applies', ->
    async.applyEach(applyOneTwoThree(call_order = []), 5).then ->
      deepEqual call_order, ['two', 'one', 'three']

  it 'partially applies', ->
    async.applyEach(applyOneTwoThree(call_order = []))(5).then ->
      deepEqual call_order, ['two', 'one', 'three']

describe 'applyEachSeries()', ->
  it 'runs serially', ->
    async.applyEachSeries(applyOneTwoThree(call_order = []), 5).then ->
      deepEqual call_order, ['one', 'two', 'three']

describe 'compose()', ->
  it 'composes functions', ->
    add2 = (n) ->
      equal n, 3
      Q.delay(50).thenResolve n+2
    mul3 = (n) ->
      equal n, 5
      Q.delay(15).thenResolve n*3
    add1 = (n) ->
      equal n, 15
      Q.delay(100).thenResolve n+1
    add2mul3add1 = async.compose add1, mul3, add2
    becomes add2mul3add1(3), 16

  it 'handles errors', ->
    testerr = new Error 'test'

    add2 = (n) ->
      equal n, 3
      Q.delay(50).thenResolve n+2
    mul3 = (n) ->
      equal n, 5
      Q.delay(15).thenReject testerr
    add1 = (n) ->
      fail 'add1 should not get called'
      Q.delay(100).thenResolve n+1
    add2mul3add1 = async.compose add1, mul3, add2
    isRejected add2mul3add1(3), testerr

  it 'binds properly', ->
    testerr = new Error 'test'
    testcontext = name: 'foo'

    add2 = (n) ->
      equal this, testcontext
      Q.delay(50).thenResolve n+2
    mul3 = (n) ->
      equal this, testcontext
      Q.delay(15).thenResolve n*3
    add2mul3 = async.compose mul3, add2
    becomes add2mul3.call(testcontext, 3), 15

describe 'auto()', ->
  it 'runs', ->
    callOrder = []
    async.auto(
      task1: ['task2', -> Q.delay(300).then -> callOrder.push 'task1']
      task2: -> Q.delay(50).then -> callOrder.push 'task2'
      task3: ['task2', -> callOrder.push 'task3']
      task4: ['task1', 'task2', -> callOrder.push 'task4']
      task5: ['task2', -> Q.delay(200).then -> callOrder.push 'task5']
      task6: ['task2', -> Q.delay(100).then -> callOrder.push 'task6']
    ).then ->
      deepEqual callOrder,
        ['task2', 'task3', 'task6', 'task5', 'task1', 'task4']


  it 'petrifies', ->
    callOrder = []
    async.auto(
      task1: ['task2', -> Q.delay(100).then -> callOrder.push 'task1']
      task2: -> Q.delay(200).then -> callOrder.push 'task2'
      task3: ['task2', -> callOrder.push 'task3']
      task4: ['task1', 'task2', -> callOrder.push 'task4']
    ).then ->
      deepEqual callOrder, ['task2', 'task3', 'task1', 'task4']

  it 'has results', ->
    callOrder = []
    async.auto(
      task1: [
        'task2'
        (results) ->
          equal results.task2, 'task2'
          Q.delay(25).then ->
            callOrder.push 'task1'
            ['task1a', 'task1b']
      ]
      task2: -> Q.delay(50).then ->
        callOrder.push 'task2'
        'task2'
      task3: [
        'task2'
        (results) ->
          equal results.task2, 'task2'
          callOrder.push 'task3'
          undefined
      ]
      task4: [
        'task1'
        'task2'
        (results) ->
          deepEqual results.task1, ['task1a', 'task1b']
          equal results.task2, 'task2'
          callOrder.push 'task4'
          'task4'
      ]
    ).then (results) ->
      deepEqual callOrder, ['task2', 'task3', 'task1', 'task4']
      deepEqual results,
        task1: ['task1a', 'task1b']
        task2: 'task2'
        task3: undefined
        task4: 'task4'

  it 'runs with an empty object', -> async.auto {}

  it 'errors out properly', ->
    isRejected async.auto(
      task1: -> throw 'testerror'
      task2: ['task1', -> fail 'task2 should not be called']
      task3: -> throw 'testerror2'
    ), /^testerror$/

describe 'waterfall()', ->
  it 'runs in the proper order', ->
    call_order = []
    async.waterfall([
      ->
        call_order.push 'fn1'
        Q.delay(0).thenResolve ['one', 'two']
      ([arg1, arg2]) ->
        call_order.push 'fn2'
        equal arg1, 'one'
        equal arg2, 'two'
        Q.delay(25).thenResolve [arg1, arg2, 'three']
      ([arg1, arg2, arg3]) ->
        call_order.push 'fn3'
        deepEqual [arg1, arg2, arg3], ['one', 'two', 'three']
        'four'
      (arg4) ->
        call_order.push 'fn4'
        'test'
    ]).then (result) ->
      equal result, 'test'
      deepEqual call_order, ['fn1', 'fn2', 'fn3', 'fn4']

  it 'handles an empty array', -> async.waterfall []

  it 'handles errors', ->
    isRejected async.waterfall([
      -> throw 'errzor'
      -> fail 'next function should not be called'
    ]), /^errzor$/

describe 'parallel()', ->
  it 'returns proper results', ->
    call_order = []
    async.parallel(getFunctionsArray call_order).then (results) ->
      deepEqual call_order, [3, 1, 2]
      deepEqual results, [1, 2, [3, 3]]

  it 'handles an empty array', ->
    becomes async.parallel([]), []
  
  it 'handles errors', ->
    isRejected(
      async.parallel([ (-> throw 'error1'), -> throw 'error2' ])
      /^error1$/
    )

  it 'accepts an object', ->
    call_order = []
    async.parallel(getFunctionsObject call_order).then (results) ->
      deepEqual call_order, [3, 1, 2]
      deepEqual results, one: 1, two: 2, three: [3, 3]

describe 'parallelLimit()', ->
  it 'returns proper results', ->
    call_order = []
    async.parallelLimit(getFunctionsArray(call_order), 2).then (results) ->
      deepEqual call_order, [1, 3, 2]
      deepEqual results, [1, 2, [3, 3]]

  it 'handles an empty array', ->
    becomes async.parallelLimit([], 2), []

  it 'handles errors', ->
    isRejected(
      async.parallelLimit([(-> throw 'error1'), -> throw 'error2'], 1)
      /^error1$/
    )

  it 'accepts an object', ->
    call_order = []
    async.parallelLimit(getFunctionsObject(call_order), 2).then (results) ->
      deepEqual call_order, [1, 3, 2]
      deepEqual results, one: 1, two: 2, three: [3, 3]

describe 'series()', ->
  it 'returns proper results', ->
    call_order = []
    async.series(getFunctionsArray call_order).then (results) ->
      deepEqual results, [1, 2, [3, 3]]
      deepEqual call_order, [1, 2, 3]

  it 'handles an empty array', ->
    becomes async.series([]), []

  it 'handles errors', ->
    isRejected(
      async.series([
        -> throw 'error1'
        ->
          fail 'should not be called'
          'error2'
      ])
      /^error1$/
    )

  it 'accepts an object', ->
    call_order = []
    async.series(getFunctionsObject call_order).then (results) ->
      deepEqual results, one: 1, two: 2, three: [3,3]
      deepEqual call_order, [1,2,3]

describe 'each()', ->
  it 'runs in parallel', ->
    args = []
    async.each([1, 3, 2], eachIterator.bind(this, args)).then ->
      deepEqual args, [1, 2, 3]

  it 'accepts an empty array', ->
    async.each([], -> fail 'iterator should not be called')

  it 'handles errors', ->
    isRejected async.each([1, 2, 3], -> throw 'error1'), /^error1$/

  it 'is aliased to forEach', -> equal async.forEach, async.each

describe 'eachSeries()', ->
  it 'returns proper results', ->
    args = []
    async.eachSeries([1, 3, 2], eachIterator.bind(this, args)).then ->
      deepEqual args, [1, 3, 2]

  it 'accepts an empty array', ->
    async.eachSeries([], -> fail 'iterator should not be called')

  it 'handles errors', ->
    call_order = []
    async.eachSeries([1, 2, 3], (x) ->
      call_order.push x
      throw 'error1'
    )
    .then(-> fail 'then() should not be invoked')
    .catch (err) ->
      equal err, 'error1'
      deepEqual call_order, [1]

  it 'is aliased to forEachSeries', ->
    equal async.forEachSeries, async.eachSeries

describe 'eachLimit()', ->
  it 'accepts an empty array', ->
    async.eachLimit([], 2, -> fail 'iterator should not be called')

  it 'can handle limit < input.length', ->
    args = []
    arr = [0..9]
    async.eachLimit(arr, 2, (x) -> Q.delay(x*5).then -> args.push x).then ->
      deepEqual args, arr

  it 'can handle limit = input.length', ->
    args = []
    arr = [0..9]
    async.eachLimit(arr, arr.length, eachIterator.bind(this, args)).then ->
      deepEqual args, arr

  it 'can handle limit > input.length', ->
    args = []
    arr = [0..9]
    async.eachLimit(arr, 20, eachIterator.bind(this, args)).then ->
      deepEqual args, arr

  it 'can handle limit = 0', ->
    async.eachLimit([0..5], 0, -> fail 'iterator should not be called')

  it 'can handle errors', ->
    isRejected(
      async.eachLimit [0,1,2], 3, (x) -> throw 'error1' if x is 2
      /^error1$/
    )

  it 'is aliased to forEachLimit', -> equal async.forEachLimit, async.eachLimit

describe 'map()', ->
  it 'returns proper results', ->
    call_order = []
    async.map([1, 3, 2], mapIterator.bind(this, call_order)).then (results) ->
      deepEqual call_order, [1, 2, 3]
      deepEqual results, [2, 6, 4]

  it 'does not modify original array', ->
    a = [1, 2, 3]
    async.map(a, (x) -> x*2).then (results) ->
      deepEqual results, [2, 4, 6]
      deepEqual a, [1, 2, 3]

  it 'handles errors', ->
    isRejected async.map([1, 2, 3], -> throw 'error1'), /^error1$/

describe 'mapSeries()', ->
  it 'returns proper results', ->
    call_order = []
    async.mapSeries([1, 3, 2], mapIterator.bind(this, call_order)).then (res) ->
      deepEqual call_order, [1, 3, 2]
      deepEqual res, [2, 6, 4]

  it 'handles errors', ->
    isRejected async.mapSeries([1, 2, 3], -> throw 'error1'), /^error1$/

describe 'mapLimit()', ->
  it 'accepts an empty array', ->
    async.mapLimit [], 2, -> fail 'iterator should not be called'

  it 'can handle limit < input.length', ->
    call_order = []
    async.mapLimit([2,4,3], 2, mapIterator.bind(this, call_order)).then (res) ->
      deepEqual call_order, [2, 4, 3], 'proper order'
      deepEqual res, [4, 8, 6], 'right results'

  it 'can handle limit = input.length', ->
    args = []
    arr = [0..9]
    async.mapLimit(arr, arr.length, mapIterator.bind(this, args)).then (res) ->
      deepEqual args,  arr
      deepEqual res, arr.map (n) -> n*2

  it 'can handle limit > input.length', ->
    call_order = []
    arr = [0..9]
    async.mapLimit(arr, 20, mapIterator.bind(this, call_order)).then (res) ->
      deepEqual call_order, arr
      deepEqual res, arr.map (n) -> n*2

  it 'can handle limit = 0', ->
    async.mapLimit([0..5], 0, -> fail 'iterator should not be called')

  it 'can handle errors', ->
    isRejected(
      async.mapLimit [0,1,2], 3, (x) -> throw 'error1' if x is 2
      /^error1$/
    )

describe 'reduce()', ->
  it 'returns proper result', ->
    call_order = []
    async.reduce([1, 2, 3], 0, (a, x) ->
      call_order.push x
      a + x
    ).then (res) ->
      equal res, 6
      deepEqual call_order, [1, 2, 3]

  it 'works async', ->
    becomes async.reduce([1, 3, 2], 0, (a, x) ->
      Q.delay(Math.random()*100).thenResolve a+x
    ), 6

  it 'handles errors', ->
    isRejected async.reduce([1, 2, 3], 0, -> throw 'error1'), /^error1$/

  it 'is aliased to inject', -> equal async.inject, async.reduce
  it 'is aliased to foldl', -> equal async.foldl, async.reduce

describe 'reduceRight()', ->
  it 'returns proper result', ->
    call_order = []
    a = [1, 2, 3]
    async.reduceRight(a, 0, (a, x) ->
      call_order.push x
      a + x
    ).then (res) ->
      equal res, 6
      deepEqual call_order, [3, 2, 1]
      deepEqual a, [1, 2, 3]

  it 'is aliased to foldr', -> equal async.foldr, async.reduceRight

describe 'filter()', ->
  it 'returns proper results', ->
    becomes async.filter([3, 1, 2], filterIterator), [3, 1]

  it 'does not modify input', ->
    a = [3, 1, 2]
    async.filter(a, (x) -> Q x % 2).then (res) ->
      deepEqual res, [3,1]
      deepEqual a, [3, 1, 2]

  it 'is aliased to select', -> equal async.select, async.filter

describe 'filterSeries()', ->
  it 'returns proper results', ->
    becomes async.filterSeries([3, 1, 2], filterIterator), [3, 1]

  it 'is aliased to selectSeries', ->
    equal async.selectSeries, async.filterSeries

describe 'reject()', ->
  it 'returns proper results', ->
    becomes async.reject([3, 1, 2], filterIterator), [2]

  it 'does not modify input', ->
    a = [3, 1, 2]
    async.reject(a, (x) -> Q x % 2).then (res) ->
      deepEqual res, [2]
      deepEqual a, [3, 1, 2]

describe 'rejectSeries()', ->
  it 'returns proper results', ->
    becomes async.rejectSeries([3, 1, 2], filterIterator), [2]

describe 'some()', ->
  it 'finds something', ->
    becomes async.some([3, 1, 2], (x) -> Q.delay(0).thenResolve x is 1), true

  it 'finds nothing', ->
    becomes async.some([3, 2, 1], (x) -> Q x is 10), false

  it 'is aliased to any', -> equal async.any, async.some

  it 'returns early on match', ->
    call_order = []
    async.some([1, 2, 3], (x) -> Q.delay(x*25).then ->
      call_order.push x
      x is 1
    ).then(-> call_order.push 'resolved')
     .delay(100)
     .then(-> deepEqual call_order, [1, 'resolved', 2, 3])

describe.only 'every()', ->
  it 'matches everything', ->
    becomes async.every([1, 2, 3], (x) -> Q.delay(0).thenResolve x < 4), true

  it 'matches not everything', ->
    becomes async.every([1, 2, 3], (x) -> Q.delay(0).thenResolve x % 2), false

  it 'is aliased to all', -> equal async.all, async.every

  it 'returns early on mis-match', ->
    call_order = []
    async.every([1, 2, 3], (x) -> Q.delay(x*25).then ->
      call_order.push x
      x is 1
    ).then(-> call_order.push 'resolved')
     .delay(100)
     .then(-> deepEqual call_order, [1, 2, 'resolved', 3])

describe 'detect()', ->
describe 'detectSeries()', ->
describe 'sortBy()', ->
describe 'concat()', ->
describe 'concatSeries()', ->
describe 'whilst()', ->
describe 'until()', ->
describe 'doWhilst()', ->
describe 'doUntil()', ->
describe 'forever()', ->
describe 'queue()', ->
describe 'cargo()', ->
describe 'times()', ->
describe 'timesSeries()', ->
describe 'memoize()', ->
describe 'unmemoize()', ->
describe 'log()', ->
describe 'dir()', ->
