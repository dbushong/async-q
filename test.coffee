async = require './'
Q     = require 'q'

require('mocha-as-promised')()
chai = require 'chai'
chai.use require 'chai-as-promised'
{assert} = chai

eachIterator = (args, x) ->
  Q.delay(x*25).then -> args.push x

mapIterator = (call_order, x) ->
  Q.delay(x*25).then ->
    call_order.push x
    x*2

filterIterator = (x) ->
  Q.delay(x*25).thenResolve x % 2

detectIterator = (call_order, x) ->
  Q.delay(x*25).then ->
    call_order.push x
    x is 2

eachNoCallbackIterator = (test, x) ->
  test

it 'forever()', ->
  counter = 0
  assert.isRejected async.forever(->
    throw 'too big!' if ++counter is 50
    Q(counter)
  ), /^too big!$/

applyOneTwoThree = (call_order) ->
  [
    (val) ->
      assert.equal val, 5
      Q.delay(100).then ->
        call_order.push 'one'
        1
    (val) ->
      assert.equal val, 5
      Q.delay(50).then ->
        call_order.push 'two'
        2
    (val) ->
      assert.equal val, 5
      Q.delay(150).then ->
        call_order.push 'three'
        3
  ]

describe 'applyEach()', ->
  it 'immediately applies', ->
    async.applyEach(applyOneTwoThree(call_order = []), 5).then ->
      assert.deepEqual call_order, ['two', 'one', 'three']

  it 'partially applies', ->
    async.applyEach(applyOneTwoThree(call_order = []))(5).then ->
      assert.deepEqual call_order, ['two', 'one', 'three']

it 'applyEachSeries()', ->
  async.applyEachSeries(applyOneTwoThree(call_order = []), 5).then ->
    assert.deepEqual call_order, ['one', 'two', 'three']

describe 'compose()', ->
  it 'composes functions', ->
    add2 = (n) ->
      assert.equal n, 3
      Q.delay(50).thenResolve n+2
    mul3 = (n) ->
      assert.equal n, 5
      Q.delay(15).thenResolve n*3
    add1 = (n) ->
      assert.equal n, 15
      Q.delay(100).thenResolve n+1
    add2mul3add1 = async.compose add1, mul3, add2
    assert.eventually.equal add2mul3add1(3), 16

  it 'handles errors', ->
    testerr = new Error 'test'

    add2 = (n) ->
      assert.equal n, 3
      Q.delay(50).thenResolve n+2
    mul3 = (n) ->
      assert.equal n, 5
      Q.delay(15).thenReject testerr
    add1 = (n) ->
      assert.fail 'add1 should not get called'
      Q.delay(100).thenResolve n+1
    add2mul3add1 = async.compose add1, mul3, add2
    assert.isRejected add2mul3add1(3), testerr

  it 'binds properly', ->
    testerr = new Error 'test'
    testcontext = name: 'foo'

    add2 = (n) ->
      assert.equal this, testcontext
      Q.delay(50).thenResolve n+2
    mul3 = (n) ->
      assert.equal this, testcontext
      Q.delay(15).thenResolve n*3
    add2mul3 = async.compose mul3, add2
    assert.eventually.equal add2mul3.call(testcontext, 3), 15

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
      assert.deepEqual callOrder,
        ['task2', 'task3', 'task6', 'task5', 'task1', 'task4']


  it 'petrifies', ->
    callOrder = []
    async.auto(
      task1: ['task2', -> Q.delay(100).then -> callOrder.push 'task1']
      task2: -> Q.delay(200).then -> callOrder.push 'task2'
      task3: ['task2', -> callOrder.push 'task3']
      task4: ['task1', 'task2', -> callOrder.push 'task4']
    ).then ->
      assert.deepEqual callOrder, ['task2', 'task3', 'task1', 'task4']

  it 'has results', ->
    callOrder = []
    async.auto(
      task1: [
        'task2'
        (results) ->
          assert.equal results.task2, 'task2'
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
          assert.equal results.task2, 'task2'
          callOrder.push 'task3'
          undefined
      ]
      task4: [
        'task1'
        'task2'
        (results) ->
          assert.deepEqual results.task1, ['task1a', 'task1b']
          assert.equal results.task2, 'task2'
          callOrder.push 'task4'
          'task4'
      ]
    ).then (results) ->
      assert.deepEqual callOrder, ['task2', 'task3', 'task1', 'task4']
      assert.deepEqual results,
        task1: ['task1a', 'task1b']
        task2: 'task2'
        task3: undefined
        task4: 'task4'

  it 'runs with an empty object', -> async.auto {}

  it 'errors out properly', ->
    assert.isRejected async.auto(
      task1: -> throw 'testerror'
      task2: ['task1', -> assert.fail 'task2 should not be called']
      task3: -> throw 'testerror2'
    ), /^testerror$/
