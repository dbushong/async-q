fs           = require 'fs'
CoffeeScript = require 'coffee-script'

md = fs.readFileSync(process.argv[2], 'utf8')
  .replace /The examples[\s\S]+?if you like\./,
    'You can also view the below examples [in CoffeeScript](README.md).'

process.stdout.write md.replace /```coffee\n([\S\s]+?)\n```/g, (m, coffee) ->
  try
    js = CoffeeScript.compile coffee, bare: true
  catch e
    throw "Error compiling CoffeeScript snippet: #{e}\n#{coffee}"

  # replace single line /* foo */ with // foo
  js = js.replace(/((?:^|\n)[ ]*)\/\*(.+)\*\/[ ]*\n/g, "$1//$2")
         .replace(/\s+\*\/\n\n/g, ' */\n')

  "```js\n#{js}```"
