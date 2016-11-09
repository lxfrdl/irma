module.exports = (settings)->
  Promise = require "promise"
  Path = require "path"
  ESHelper = require "./es-helper"
  Express = require "express"
  ByRelevance = require "./config-types/by-relevance"
  morgan = require "morgan"
  errorHandler = require "errorhandler"

  bulk = require "bulk-require"

  es = ESHelper(settings.elasticSearch)
  jsonP = (f)->
    (req,res)->
      success = (obj)->
        res.json obj
      failure = (err)->
        console.error "error",err.stack||err
        console.error "error",err
        res.status(err.status).send err
      try
        Promise.resolve(f(req)).done success,failure
      catch err
        console.error "error",err.stack||err
        res.status(500).send err



  service = Express()
  if settings.pretty
    service.set 'json spaces', 2
  service.use Express.static( Path.join(__dirname, '..', 'static'))
  service.set 'port', settings.port
  service.use morgan('dev')
  service.use errorHandler()
  service.get '/', (req,res)->
    res.json
      apiVersion: require("../package.json").version



  service.get '/:type/search', jsonP ( (req)->
    options =
      offset: req.query.offset
      limit:req.query.limit
      sorter:sort(req.params.type,req.query)
      type:req.params.type
    
    options.types = settings.types


    es.search req.query, options
  )



  service.get '/:type/random', jsonP (req)->
    options =
      attributes: settings.types[req.params.type].attributes
      seed: req.query.seed ? Math.random()
      type: req.params.type

    es.random req.query, options

  service.get '/:type/:id' , jsonP( (req)->
    es.fetch(req.params.id,req.params.type).then (body)->
      body._source
  )

  sort = (type,query)->
    s = query.sort ? "relevance,desc"
    [attr0,direction] = s.split ','
    criterion = attr0 ? "relevance"
    sorter = settings.types[type]?.sort?[criterion] ? new ByRelevance()
    sorter = sorter.direction(direction)
    #console.log 'criterion', criterion
    #console.log 'direction', direction
    #console.log 'sort', sort
    sorter

  #service.disable 'etag'
  service


