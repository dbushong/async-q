Q      = require 'q'
throat = require 'throat'

aliases =
  each:         ['map']
  eachSeries:   ['mapSeries']
  eachLimit:    ['mapLimit']
  filter:       ['select']
  filterSeries: ['selectSeries']
  reduce:       ['inject', 'foldl']
  reduceRight:  ['foldr']
  some:         ['any']
  every:        ['all']

consoleFn = (name) -> (fn, args...) ->
  Q.fapply(fn, args)
    .catch((err) -> console?.error? err)
    .then((res) -> console?[name]? res)

processArrayOrObject = (tasks, fn) ->
  arr = if tasks.constructor is Array
    tasks
  else
    keys = (key for key of tasks)
    (tasks[key] for key in keys)

  Q.try(fn, arr).then (results) ->
    if keys
      res = {}
      res[key] = results[i] for key, i in keys
      res
    else
      results

module.exports = async =
  # type sig for each{,Series}()
  # [a] -> (a -> P b) -> P [b]
  each: (arr, iterator) -> Q.all arr.map (a) -> Q.try iterator, a

  eachSeries: (arr, iterator) -> async.series arr.map (a) -> -> iterator a

  # [a] -> Number -> (a -> P b) -> P [b]
  eachLimit: (arr, limit, iterator) ->
    async.parallelLimit arr.map((a) -> -> iterator a), limit

  # type sig for {filter,reject}{,Series}()
  # [a] -> (a -> P Boolean) -> P [a]
  filter: (arr, iterator, reject=false) ->
    Q.all(arr.map (a) -> Q.try(iterator, a).then (ok) -> [ok, a])
     .then (res) -> res.filter(([ok]) -> reject ^ ok).map ([ok, a]) -> a

  filterSeries: (arr, iterator, reject=false) ->
    async.series(arr.map (a) -> -> iterator(a).then (ok) -> [ok, a])
          .then (res) -> res.filter(([ok]) -> reject ^ ok).map ([ok, a]) -> a

  reject: (arr, iterator) -> async.filter arr, iterator, true

  rejectSeries: (arr, iterator) -> async.filterSeries arr, iterator, true

  # type sig for reduce{,Right}()
  # [a] -> b -> (b -> a -> P b) -> P b
  reduce: (arr, memo, iterator, right=false) ->
    arr[if right then 'reduceRight' else 'reduce'](
      (res, a) -> res.then((b) -> iterator b, a)
      Q(memo)
    )

  reduceRight: (arr, memo, iterator) -> async.reduce arr, memo, iterator, true

  # type sig for detect{,Series}()
  # [a] -> (a -> P Boolean) -> P a
  detect: (arr, iterator) -> async.filter(arr, iterator).get 0

  detectSeries: (arr, iterator) -> async.filterSeries(arr, iterator).get 0

  # [a] -> (a -> P b) -> [a]
  # basically a swartzian transform
  sortBy: (arr, iterator) ->
    Q.all(arr.map (a) -> Q.try(iterator, a).then (b) -> [b, a]).then (res) ->
      res.sort((x, y) ->
        if x[0] < y[0]
          -1
        else if x[0] > y[0]
          1
        else
          0
      ).map (x) -> x[1]

  # type sig for some() & every()
  # [a] -> (a -> P Boolean) -> P Boolean
  # TODO: have these bail "early" when reach known state?
  some: (arr, iterator) ->
    async.filter(arr, iterator).then (passed) -> passed.length > 0

  every: (arr, iterator) ->
    async.reject(arr, iterator).then (rejected) -> rejected.length is 0

  # type sig for concat{,Series}()
  # [a] -> (a -> P [b]) -> [b]
  concat: (arr, iterator) ->
    async.map(arr, iterator)
      .then (res) -> res.reduce ((a,b) -> a.concat b), []

  concatSeries: (arr, iterator) ->
    async.reduce arr, [], (res, a) -> iterator(a).then (bs) -> res.concat bs

  # type sig for series() & parallel()
  # [-> P *] -> P [*]
  # {-> P *} -> P {*}
  series: (tasks) ->
    processArrayOrObject tasks, (arr) ->
      results = []
      arr.reduce(
        (res, task) -> res.then(task).then results.push.bind(results)
        Q()
      ).then(-> results)

  parallel: (tasks) -> processArrayOrObject tasks, (arr) -> Q.all arr.map Q.try

  parallelLimit: (tasks, limit) ->
    processArrayOrObject tasks, (arr) -> Q.all arr.map throat limit

  # FIXME: should we put a limit on these? JS probably doesn't have tail
  # recursion optimization
  # (->) -> (-> P) -> P
  whilst: (test, fn, invert=false) ->
    if invert ^ test()
      Q.try(fn).then -> async.whilst test, fn
    else
      Q()
  until: (test, fn) -> async.whilst test, fn, true

  # (-> P) -> (->) -> P
  doWhilst: (fn, test) -> fn().then -> async.whilst test, fn
  doUntil:  (fn, test) -> fn().then -> async.whilst test, fn, true

  forever: (fn) -> Q.try(fn).then fn

  # you'd be silly to use this instead of just .then().then(), but hey
  # [(* -> P *)] -> P *
  waterfall: (tasks) -> tasks.reduce ((res, task) -> res.then(task)), Q()

  # [(* -> P *)]... -> (* -> P *)
  compose: (fns...) -> (arg) ->
    that = this
    async.waterfall fns.concat(-> Q arg).reverse().map (fn) -> ->
      fn.apply(that, arguments)

  applyEach: (fns, args...) ->
    doApply = (a...) -> Q.all fns.map (fn) -> Q.fapply fn, a
    if args.length
      doApply args...
    else
      doApply

  applyEachSeries: (fns, args...) ->
    doApply = (a...) -> async.series fns.map (fn) -> -> fn a...
    if args.length
      doApply args...
    else
      doApply

  # (a -> P) -> Number -> P
  queue: (worker, concurrency=1) ->
    _insert = (data, op='push') ->
      data     = [data] unless data.constructor is Array
      promises = []
      for task in data
        item = data: task, defer: Q.defer()
        promises.push item.defer.promise
        q.tasks[op] item
        q.saturated?() if q.tasks.length is concurrency
        process.nextTick q.process
      if promises.length is 1 then promises[0] else promises

    workers = 0

    q =
      concurrency: concurrency
      tasks:     []
      saturated: null
      empty:     null
      drain:     null
      push:      (data) -> _insert data
      unshift:   (data) -> _insert data, 'unshift'
      length:    -> q.tasks.length
      running:   -> workers
      process:   ->
        if workers < q.concurrency and q.tasks.length
          task = q.tasks.shift()
          q.empty?() if q.tasks.length is 0
          workers++
          Q.try(worker, task.data)
            .catch(task.defer.reject.bind task.defer)
            .then (res) ->
              workers--
              task.defer.resolve res
              q.drain?() if q.tasks.length + workers is 0
              q.process()

  # (a -> P) -> Number -> P
  cargo: (worker, payload=null) ->
    working = false
    tasks   = []
    cargo   =
      tasks:     tasks
      payload:   payload
      saturated: null
      empty:     null
      drain:     null
      length:    -> tasks.length
      running:   -> working
      push: (data) ->
        data     = [data] unless data.contructor is Array
        promises = data.map (task) ->
          d = Q.defer()
          tasks.push data: task, defer: d
          d.promise
        cargo.saturated?() if tasks.length is payload
        process.nextTick cargo.process
        if promises.length is 1 then promises[0] else promises
      process: ->
        return if working
        return cargo.drain?() if tasks.length is 0
        ts = if payload? then tasks.splice 0, payload else tasks.splice 0
        cargo.empty?()
        working = true
        Q.try(worker, ts.map (t) -> t.data)
         .catch (err) ->
           ts.forEach (task) -> task.defer.reject err
         .then (res) ->
           working = false
           ts.forEach (task) -> task.defer.resolve res
           cargo.process()

  # { [String..., (* -> P *)] } -> P { * }
  auto: (tasks) ->
    total    = (key for own key of tasks).length
    qdef     = Q.defer()
    results  = {}
    running  = {}
    finished = false

    do checkPending = ->
      return if finished

      # check if we're done
      done = (key for key of results)
      if done.length is total
        qdef.resolve results
        finished = true
        return

      for name, stuff of tasks
        continue if name in done # skip ones we've finished

        if 'function' is typeof stuff
          reqs = []
          fn   = stuff
        else
          reqs = stuff[..]
          fn   = reqs.pop()

        # if all requisites are satisifed for this task
        if !running[name] and reqs.reduce ((ok,req) -> ok and req in done), true
          do (name) ->
            running[name] = true
            Q.try(fn, results)
              .catch(qdef.reject.bind qdef)
              .then (res) ->
                results[name] = res
                checkPending()
              .done()

    qdef.promise

  # callback-specific utility functions: won't implement?
  iterator: -> throw new Error 'NOT YET(?) IMPLEMENTED'
  apply:    -> throw new Error 'NOT YET(?) IMPLEMENTED'
  nextTick: -> throw new Error 'NOT YET(?) IMPLEMENTED'

  # Number -> (-> P) -> P
  times: (n, fn) -> async.parallel [fn for i in 1..n]

  timesSeries: (n, fn) -> async.series [fn for i in 1..n]

  memoize: (fn, hasher) ->
    hasher ||= (x) -> x
    cache = {}
    mem = (args...) ->
      key = hasher args...
      return Q cache[key] if key of cache
      Q.fapply(fn, args).then (res) -> cache[key] = res
    mem.unmemoized = fn
    mem.memo = cache
    mem

  unmemoize: (fn) -> fn.unmemoized or fn

  log: consoleFn 'log'

  dir: consoleFn 'dir'

for orig, akas of aliases
  async[aka] = async[orig] for aka in akas
