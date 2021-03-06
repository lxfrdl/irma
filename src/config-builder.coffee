Promise = require "bluebird"
functionArguments = require "function-arguments"
Merge = require "./merger"
compose = (funs...)-> funs.reduceRight (a,b)->(x...)-> b a x...
defaults = require("./default-settings")
path = require "path"
bulk = require "bulk-require"
{isArray} = require "util"
sigmatch = require "sigmatch"
LoadYaml = require "./load-yaml"
ConfigNode = require "./config-node"
loadConfigTypes = (dirs)->
  dirs
    .map (dir)-> bulk dir, '*'
    .reduce ((a,b)->merge a,b), {}

merge = Merge customMerge: (lhs, rhs, pass)->
  if rhs instanceof ConfigNode
    if rhs.merge? then rhs.merge(lhs, merge) else rhs
  else
    pass
  

resolveStaticPaths = ( obj)->
  throw new Error("häh?"+obj) if typeof obj isnt "object"
  return null unless obj?
  dir = obj.__dirname ? if obj.__filename? then path.dirname obj.__filename
  return obj unless dir?

  replaceEntries = (blockName)->
    if obj[blockName]?
      tmp = {}
      tmp[key] = path.resolve dir, value for key, value of (obj[blockName] ? {})
      obj[blockName] = tmp
  replaceEntries blockName for blockName in ['static', 'dynamic']

  obj

resolve = ({file, required, content, configTypes={}})->
  if file?
    if content?
      merge {__filename:file, __dirname:path.dirname file}, content
    else
      loadYaml = LoadYaml configTypes, (not required)
      content = loadYaml file
      if content?
        merge content, __filename:file, __dirname:path.dirname file
      else null
  else
    content

mergeTwoConfigs = (a={},b={})->
  filesA = a.__files ? if a.__filename? then [a.__filename] else []
  filesB = b.__files ? if b.__filename? then [b.__filename] else []
  files = filesA.concat filesB
  c = merge a, b
  delete c.__filename
  delete c.__dirname
  c.__files = files if files.length > 0
  c

mergeConfigs = (configs...)->
  configs.reduce mergeTwoConfigs

identity = (x)->Promise.resolve x

load_ = ({required=true, envVars=[], constructFileName})->
  (cfg)->
    env = envVars.map (name)->cfg.__env?[name]
    file = path.resolve constructFileName env...
    newContent = resolveStaticPaths resolve
      file:file
      required:required
      configTypes: cfg.__types
      content:null

    if envVars.length >0
      unit mergeConfigs cfg, newContent, __usedEnvVars:envVars
    else
      unit mergeConfigs cfg, newContent

load = (opts)->sigmatch (match)->
  match "s", (file)->
    load_ merge opts, constructFileName: (->file)
  match "a,f", (deps, file)->
    load_ merge opts, constructFileName: file, envVars: deps
  match "f", (fun)->
    deps = functionArguments fun
    load_ merge opts, constructFileName: fun, envVars: deps
  match ".*", -> throw new Error "unsupported call signature"

arrows =
  unit: (cfg)-> wrap cfg, identity
  typePath: (dirs0...)->(cfg)->
    dirs = dirs0.map (d)->path.resolve d
    unit (
      if dirs.length > 0
        merge cfg, __types: loadConfigTypes( dirs), __typePath:dirs
      else
        cfg
      )
  load: load required:true
  tryLoad: load required: false
  add: (obj, file) -> (cfg) ->
    unit mergeConfigs cfg, resolveStaticPaths resolve
      file: if file then path.resolve file
      content:obj
  then: (f)->if not f? then unit else ((cfg)->wrap cfg, f)
unit = arrows.unit

wrap = (cfg=defaults, action=identity)->
  bind= (f=unit)->
    m = f cfg
    wrap m._cfg, (env, finalCfg, argv0)->
      Promise.resolve action env, finalCfg, argv0
        .then (argv1)->m.action env, finalCfg, argv1
  build = ()->cfg
  run= (env,argv)->
    action env,build() ,argv

  instance = bind: bind, action: action, _cfg:cfg, run:run, build:build
  for key,value of arrows when key isnt "unit"
    do (key,value)->instance[key] = (args...)->@bind value args...
  instance

# the built-in functions are also made available as static "methods"
module.exports= wrap
module.exports[key]=value for key,value of arrows

