async = require './'
Q     = require 'q'

require('mocha')
chai = require 'chai'
chai.use require 'chai-as-promised'
{ assert: { strictEqual: equal, deepEqual, isRejected, fail, becomes, ok }
} = chai

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

  it 'accepts a promise for a function', ->
    counter = 0
    isRejected async.forever(Q(->
      throw 'too big!' if ++counter is 50
      Q(counter)
    )), /^too big!$/

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

  it 'accepts a promise for an array of tasks', ->
    becomes async.waterfall(Q([
      -> 10
      (n) -> n + 30
      (n) -> n + 2
    ])), 42

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

  it 'accepts a promise', ->
    becomes async.parallel(Q(getFunctionsArray [])), [1, 2, [3, 3]]

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

  it 'accepts a promise', ->
    becomes async.parallelLimit(getFunctionsArray([]), 2), [1, 2, [3, 3]]

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

  it 'accepts a promise', ->
    becomes async.series(getFunctionsArray []), [1, 2, [3, 3]]

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

  it 'accepts promises', ->
    args = []
    async.each(Q([1, 3, 2]), Q(eachIterator.bind(this, args))).then ->
      deepEqual args, [1, 2, 3]

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

  it 'accepts promises', ->
    args = []
    async.eachSeries(Q([1, 3, 2]), Q(eachIterator.bind(this, args))).then ->
      deepEqual args, [1, 3, 2]

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

  it 'accepts promises', ->
    args = []
    arr = [0..9]
    async.eachLimit(Q(arr), Q(2), Q((x) -> Q.delay(x*5).then -> args.push x))
      .then ->
        deepEqual args, arr


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

  it 'accepts promises', ->
    becomes async.map(Q([1, 3, 2]), Q(mapIterator.bind(this, []))), [2, 6, 4]

describe 'mapSeries()', ->
  it 'returns proper results', ->
    call_order = []
    async.mapSeries([1, 3, 2], mapIterator.bind(this, call_order)).then (res) ->
      deepEqual call_order, [1, 3, 2]
      deepEqual res, [2, 6, 4]

  it 'handles errors', ->
    isRejected async.mapSeries([1, 2, 3], -> throw 'error1'), /^error1$/

  it 'accepts promises', ->
    becomes async.mapSeries(Q([1, 3, 2]), Q(mapIterator.bind(this, []))),
      [2, 6, 4]

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

  it 'accepts promises', ->
    becomes async.mapLimit(Q([2,4,3]), Q(2), Q(mapIterator.bind(this, []))),
      [4, 8, 6]

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

  it 'accepts promises', ->
    becomes async.reduce(Q([1, 3, 2]), Q(0), Q((a, x) -> a+x)), 6

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

  it 'accepts promises', ->
    becomes async.reduceRight(Q([1, 2, 3]), Q(0), Q((a, x) -> a+x)), 6

describe 'filter()', ->
  it 'returns proper results', ->
    becomes async.filter([3, 1, 2], filterIterator), [3, 1]

  it 'does not modify input', ->
    a = [3, 1, 2]
    async.filter(a, (x) -> Q x % 2).then (res) ->
      deepEqual res, [3,1]
      deepEqual a, [3, 1, 2]

  it 'is aliased to select', -> equal async.select, async.filter

  it 'accepts promises', ->
    becomes async.filter(Q([3, 1, 2]), Q(filterIterator)), [3, 1]

describe 'filterSeries()', ->
  it 'returns proper results', ->
    becomes async.filterSeries([3, 1, 2], filterIterator), [3, 1]

  it 'is aliased to selectSeries', ->
    equal async.selectSeries, async.filterSeries

  it 'accepts promises', ->
    becomes async.filterSeries(Q([3, 1, 2]), Q(filterIterator)), [3, 1]

describe 'reject()', ->
  it 'returns proper results', ->
    becomes async.reject([3, 1, 2], filterIterator), [2]

  it 'does not modify input', ->
    a = [3, 1, 2]
    async.reject(a, (x) -> Q x % 2).then (res) ->
      deepEqual res, [2]
      deepEqual a, [3, 1, 2]

  it 'accepts promises', ->
    becomes async.reject(Q([3, 1, 2]), Q(filterIterator)), [2]

describe 'rejectSeries()', ->
  it 'returns proper results', ->
    becomes async.rejectSeries([3, 1, 2], filterIterator), [2]

  it 'accepts promises', ->
    becomes async.rejectSeries(Q([3, 1, 2]), Q(filterIterator)), [2]

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

  it 'accepts promises', ->
    becomes async.some(Q([3, 1, 2]), Q((x) -> Q.delay(0).thenResolve x is 1)),
      true

describe 'every()', ->
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

  it 'accepts promises', ->
    becomes async.every(Q([1, 2, 3]), Q((x) -> Q.delay(0).thenResolve x < 4)),
      true

describe 'detect()', ->
  it 'returns proper results', ->
    call_order = []
    async.detect([3, 2, 1], detectIterator.bind(this, call_order))
      .then (res) ->
        call_order.push 'resolved'
        equal res, 2
      .delay(100)
      .then -> deepEqual call_order, [1, 2, 'resolved', 3]

  it 'returns one of multiple matches', ->
    call_order = []
    async.detect([3,2,2,1,2], detectIterator.bind(this, call_order))
      .then (res) ->
        call_order.push 'resolved'
        equal res, 2
      .delay(100)
      .then ->
        deepEqual call_order.filter((c) -> c isnt 'resolved'), [1, 2, 2, 2, 3]
        i = call_order.indexOf 'resolved'
        ok (i < 5), 'short circuited early'

  it 'handles errors', ->
    isRejected(
      async.detect([1, 2, 3], (x) -> if x is 2 then throw 'error1' else false)
      /^error1$/
    )

  it 'accepts promises', ->
    becomes async.detect(Q([1, 2, 3]), Q(detectIterator.bind(this, []))), 2

describe 'detectSeries()', ->
  it 'returns proper results', ->
    call_order = []
    async.detectSeries([3,2,1], detectIterator.bind(this, call_order))
      .then (res) ->
        call_order.push 'resolved'
        equal res, 2
      .delay(200)
      .then -> deepEqual call_order, [3, 2, 'resolved']

  it 'returns one of multiple matches', ->
    call_order = []
    async.detectSeries([3,2,2,1,2], detectIterator.bind(this, call_order))
      .then (res) ->
        call_order.push 'resolved'
        equal res, 2
      .delay(200)
      .then -> deepEqual call_order, [3, 2, 'resolved']

  it 'accepts promises', ->
    becomes async.detectSeries(Q([3,2,1]), Q(detectIterator.bind(this, []))), 2

describe 'sortBy()', ->
  it 'returns proper results', ->
    becomes(
      async.sortBy([{a:1},{a:15},{a:6}], (x) -> Q.delay(0).thenResolve x.a)
      [{a:1},{a:6},{a:15}]
    )

  it 'accepts promises', ->
    becomes async.sortBy(Q([{a:2},{a:1}]), Q((x) -> Q(x.a))), [{a:1},{a:2}]

describe 'concat()', ->
  it 'returns just-in-time results', ->
    call_order = []
    iterator = (x) ->
      Q.delay(x*25).then ->
        call_order.push x
        [x..1]
    async.concat([1,3,2], iterator).then (res) ->
      deepEqual res, [1, 2, 1, 3, 2, 1]
      deepEqual call_order, [1, 2, 3]

  it 'handles errors', ->
    isRejected async.concat([1,2,3], -> throw 'error1'), /^error1$/

  it 'accepts promises', ->
    iterator = (x) -> Q.delay(x*25).then -> [x..1]
    becomes async.concat(Q([1,3,2]), Q(iterator)), [1, 2, 1, 3, 2, 1]

describe 'concatSeries()', ->
  it 'returns ordered results', ->
    call_order = []
    iterator = (x) ->
      Q.delay(x*25).then ->
        call_order.push x
        [x..1]
    async.concatSeries([1,3,2], iterator).then (res) ->
      deepEqual res, [1,3,2,1,2,1]
      deepEqual call_order, [1,3,2]

  it 'handles errors', ->
    isRejected async.concatSeries([1,2,3], -> throw 'error1'), /^error1$/

  it 'accepts promises', ->
    iterator = (x) -> Q.delay(x*25).then -> [x..1]
    becomes async.concatSeries(Q([1,3,2]), Q(iterator)), [1,3,2,1,2,1]

describe 'until()', ->
  it 'returns proper results', ->
    call_order = []
    count = 0
    async.until(
      ->
        call_order.push ['test', count]
        count is 5
      ->
        call_order.push ['iterator', count]
        count++
    ).then ->
      deepEqual call_order, [
        ['test', 0]
        ['iterator', 0], ['test', 1]
        ['iterator', 1], ['test', 2]
        ['iterator', 2], ['test', 3]
        ['iterator', 3], ['test', 4]
        ['iterator', 4], ['test', 5]
      ]
      equal count, 5

  it 'handles test errors', ->
    isRejected async.until((-> throw 'error1'), ->), /^error1$/

  it 'handles iterator errors', ->
    isRejected async.until((-> false), -> throw 'error1'), /^error1$/

  it 'accepts promises', ->
    count = 0
    async.until(Q(-> count is 5), Q(-> count++)).then -> equal count, 5

describe 'doUntil()', ->
  it 'returns proper results', ->
    call_order = []
    count = 0
    async.doUntil(
      ->
        call_order.push ['iterator', count]
        count++
      ->
        call_order.push ['test', count]
        count is 5
    ).then ->
      deepEqual call_order, [
        ['iterator', 0], ['test', 1]
        ['iterator', 1], ['test', 2]
        ['iterator', 2], ['test', 3]
        ['iterator', 3], ['test', 4]
        ['iterator', 4], ['test', 5]
      ]
      equal count, 5

  it 'handles test errors', ->
    isRejected async.doUntil((->), -> throw 'error1'), /^error1$/

  it 'handles iterator errors', ->
    isRejected async.doUntil((-> throw 'error1'), -> false), /^error1$/

  it 'accepts promises', ->
    count = 0
    async.doUntil(Q(-> count++), Q(-> count is 5)).then -> equal count, 5

describe 'whilst()', ->
  it 'returns proper results', ->
    call_order = []
    count = 0
    async.whilst(
      ->
        call_order.push ['test', count]
        count < 5
      ->
        call_order.push ['iterator', count]
        count++
    ).then ->
      deepEqual call_order, [
        ['test', 0]
        ['iterator', 0], ['test', 1]
        ['iterator', 1], ['test', 2]
        ['iterator', 2], ['test', 3]
        ['iterator', 3], ['test', 4]
        ['iterator', 4], ['test', 5]
      ]
      equal count, 5

  it 'handles test errors', ->
    isRejected async.whilst((-> throw 'error1'), ->), /^error1$/

  it 'handles iterator errors', ->
    isRejected async.whilst((-> true), -> throw 'error1'), /^error1$/

  it 'accepts promises', ->
    count = 0
    async.whilst(Q(-> count < 5), Q(-> count++)).then -> equal count, 5

describe 'doWhilst()', ->
  it 'returns proper results', ->
    call_order = []
    count = 0
    async.doWhilst(
      ->
        call_order.push ['iterator', count]
        count++
      ->
        call_order.push ['test', count]
        count < 5
    ).then ->
      deepEqual call_order, [
        ['iterator', 0], ['test', 1]
        ['iterator', 1], ['test', 2]
        ['iterator', 2], ['test', 3]
        ['iterator', 3], ['test', 4]
        ['iterator', 4], ['test', 5]
      ]
      equal count, 5

  it 'handles test errors', ->
    isRejected async.doWhilst((->), -> throw 'error1'), /^error1$/

  it 'handles iterator errors', ->
    isRejected async.doWhilst((-> throw 'error1'), -> true), /^error1$/

  it 'accepts promises', ->
    count = 0
    async.doWhilst(Q(-> count++), Q(-> count < 5)).then -> equal count, 5

describe 'queue()', ->

  testQueue = (concurrency, changeTo=null) ->
    call_order = []
    delays = [160, 80, 240, 80]

    # worker1: --1-4
    # worker2: -2---3
    # order of completion: 2,1,4,3
    
    q = async.queue(
      (task) ->
        Q.delay(delays.shift()).then ->
          call_order.push "process #{task}"
          'arg'
      concurrency
    )
    concurrency ?= 1

    push1 = q.push(1).then (arg) ->
      equal arg, 'arg'
      call_order.push 'resolved 1'

    push2 = q.push(2).then (arg) ->
      equal arg, 'arg'
      call_order.push 'resolved 2'

    push3 = q.push(3).then (arg) ->
      equal arg, 'arg'
      call_order.push 'resolved 3'

    push4 = q.push(4)
    push4.start.then -> call_order.push 'started 4'
    push4.then (arg) ->
      equal arg, 'arg'
      call_order.push 'resolved 4'

    equal q.length(), 4, 'queue should be length 4 after all pushes'
    equal q.concurrency, concurrency,
      "concurrency should be #{concurrency} after pushes"

    if changeTo?
      concurrency = q.concurrency = changeTo

    drain = Q.promise (resolve, reject) ->
      q.on 'drain', -> process.nextTick ->
        try
          co = if concurrency is 2
            [ 'process 2', 'resolved 2'
              'process 1', 'resolved 1', 'started 4',
              'process 4', 'resolved 4'
              'process 3', 'resolved 3' ]
          else
            [ 'process 1', 'resolved 1'
              'process 2', 'resolved 2'
              'process 3', 'resolved 3', 'started 4',
              'process 4', 'resolved 4' ]
          deepEqual call_order, co, 'call_order should be correct'
          equal q.concurrency, concurrency,
            "concurrency should be #{concurrency} in drain()"
          equal q.length(), 0, 'queue should be length 0 in drain()'
          resolve()
        catch err
          reject err

    Q.all [push1, push2, push3, push4, drain]

  it 'returns proper results', -> testQueue 2

  it 'defaults to concurrency of 1', -> testQueue()

  it 'handles errors', ->
    results = []
    q = async.queue (({name}) -> throw 'fooError' if name is 'foo'), 2

    drain = Q.promise (resolve, reject) ->
      q.on 'drain', -> process.nextTick ->
        try
          deepEqual results, ['bar', 'fooError']
          resolve()
        catch err
          reject err

    push1 = q.push(name: 'bar')
      .then(-> results.push 'bar')
      .catch(-> results.push 'barError')

    push2 = q.push(name: 'foo')
      .then(-> results.push 'foo')
      .catch(-> results.push 'fooError')

    Q.all [drain, push1, push2]

  it 'allows concurrency change', -> testQueue(2, 1)

  it 'supports unshift()', ->
    queue_order = []
    q = async.queue ((task) -> queue_order.push task), 1

    Q.all([4..1].map(q.unshift.bind q)).then ->
      deepEqual queue_order, [1, 2, 3, 4]

  it 'allows pushing multiple tasks at once', ->
    call_order = []
    delays = [160,80,240,80]
    q = async.queue(
      (task) ->
        Q.delay(delays.shift()).then ->
          call_order.push "process #{task}"
          task
      2
    )

    pushes = q.push([1, 2, 3, 4]).map (p) ->
      p.then (arg) -> call_order.push "resolved #{arg}"

    equal q.length(), 4, 'queue length is 4 after bulk push'
    equal q.concurrency, 2, 'concurrency is 2 after bulk push'

    Q.all(pushes).then ->
      deepEqual call_order, [
        'process 2', 'resolved 2'
        'process 1', 'resolved 1'
        'process 4', 'resolved 4'
        'process 3', 'resolved 3'
      ]
      equal q.concurrency, 2, 'concurrency is 2 after completion'
      equal q.length(), 0, 'queue length is 0 after completion'

describe 'cargo()', ->
  it 'returns proper results', ->
    call_order = []
    delays = [160, 160, 80]

    # worker: --12--34--5-
    # order of completion: 1,2,3,4,5
    
    c = async.cargo(
      (tasks) ->
        Q.delay(delays.shift()).then ->
          call_order.push "process #{tasks}"
          'arg'
      2
    )

    push1 = c.push(1).then (arg) ->
      equal arg, 'arg'
      call_order.push 'resolved 1'

    push2 = c.push(2).then (arg) ->
      equal arg, 'arg'
      call_order.push 'resolved 2'

    equal c.length(), 2

    # async pushes
    push3 = Q.delay(60).then ->
      c.push(3).then (arg) ->
        equal arg, 'arg'
        call_order.push 'resolved 3'

    push45 = Q.delay(120).then ->
      push4 = c.push(4).then (arg) ->
        equal arg, 'arg'
        call_order.push 'resolved 4'
      equal c.length(), 2
      push5 = c.push(5).then (arg) ->
        equal arg, 'arg'
        call_order.push 'resolved 5'
      Q.all [push4, push5]

    Q.all([push1, push2, push3, push45]).then ->
      deepEqual call_order, [
        'process 1,2', 'resolved 1', 'resolved 2'
        'process 3,4', 'resolved 3', 'resolved 4'
        'process 5', 'resolved 5'
      ]
      equal c.length(), 0

  it 'allows pushing multiple tasks at once', ->
    call_order = []
    delays = [120, 40]

    # worker: -123-4-
    # order of completion: 1,2,3,4

    c = async.cargo(
      (tasks) ->
        Q.delay(delays.shift()).then ->
          call_order.push "process #{tasks}"
          tasks.join()
      3
    )

    pushes = c.push([1..4]).map (p) -> p.then (arg) ->
      call_order.push "resolved #{arg}"

    equal c.length(), 4

    Q.all(pushes).then ->
      deepEqual call_order, [
        'process 1,2,3',  'resolved 1,2,3'
        'resolved 1,2,3', 'resolved 1,2,3'
        'process 4',      'resolved 4'
      ]
      equal c.length(), 0

describe 'memoize()', ->
  it 'memoizes a function', ->
    call_order = []

    fn = (arg1, arg2) ->
      call_order.push ['fn', arg1, arg2]
      Q arg1 + arg2

    fn2 = async.memoize fn

    Q.all([
      becomes(fn2(1, 2), 3)
      becomes(fn2(1, 2), 3)
      becomes(fn2(2, 2), 4)
    ]).then -> deepEqual call_order, [['fn', 1, 2], ['fn', 2, 2]]

  it 'handles errors', ->
    fn = (arg1, arg2) -> throw 'error1'
    isRejected async.memoize(fn)(1, 2), /^error1$/

  it 'handles multiple async calls', ->
    fn = (arg1, arg2) -> Q.delay(10).then -> [arg1, arg2]
    fn2 = async.memoize fn
    Q.all [
      becomes fn2(1, 2), [1, 2]
      becomes fn2(1, 2), [1, 2]
    ]

  it 'accepts a custom hash function', ->
    fn = (arg1, arg2) -> Q arg1 + arg2
    fn2 = async.memoize fn, -> 'custom hash'
    
    Q.all [
      becomes fn2(1, 2), 3
      becomes fn2(2, 2), 3
    ]

  it 'lets you futz with the cache', ->
    fn = async.memoize (arg) -> fail 'Function should never be called'
    fn.memo.foo = 'bar'
    becomes fn('foo'), 'bar'

describe 'unmemoize()', ->
  it 'returns the original function', ->
    call_order = []
    fn = (arg1, arg2) ->
      call_order.push ['fn', arg1, arg2]
      Q arg1 + arg2

    fn2 = async.memoize fn
    fn3 = async.unmemoize fn2

    Q.all([
      becomes(fn3(1, 2), 3)
      becomes(fn3(1, 2), 3)
      becomes(fn3(2, 2), 4)
    ]).then -> deepEqual call_order, [['fn',1,2],['fn',1,2,],['fn',2,2]]

  it 'works on not-memoized functions', ->
    fn = (arg1, arg2) -> Q arg1 + arg2
    fn2 = async.unmemoize fn
    becomes fn2(1, 2), 3

describe 'times()', ->
  it 'returns proper results', ->
    becomes async.times(5, (n) -> Q n), [0..4]

  it 'maintains order', ->
    becomes async.times(3, (n) -> Q.delay((3-n)*25).thenResolve n), [0..2]

  it 'accepts n=0', ->
    async.times(0, -> fail 'iterator should not be called')

  it 'handles errors', ->
    isRejected async.times(3, -> throw 'error1'), /^error1$/

  it 'accepts promises', ->
    becomes async.times(Q(5), Q((n) -> Q n)), [0..4]

describe 'timesSeries()', ->
  it 'returns proper results', ->
    call_order = []
    async.timesSeries(
      5
      (n) ->
        Q.delay(100-n*10).then ->
          call_order.push n
          n
    ).then (res) ->
      deepEqual call_order, [0..4]
      deepEqual res, [0..4]

  it 'handles errors', ->
    isRejected async.timesSeries(5, -> throw 'error1'), /^error1$/

  it 'accepts promises', ->
    becomes async.timesSeries(Q(5), Q((n) -> Q n)), [0..4]

### FIXME spews output for some reason
['log', 'dir'].forEach (name) ->
  describe "#{name}()", ->
    it "calls console.#{name}() on results", ->
      fn = (arg1) ->
        equal arg1, 'one'
        Q.delay(0).thenResolve 'test'
      fn_err = (arg1) ->
        equal arg1, 'one'
        Q.delay(0).thenReject 'error'
      _console_fn = console[name]
      _error      = console.error
      console[name] = (val) ->
        console[name] = _console_fn
        equal val, 'test'
        equal arguments.length, 1
      async[name](fn, 'one').then ->
        console.error = (val) ->
          console.error = _error
          equal val, 'error'
        async[name] fn_err, 'one'
###
