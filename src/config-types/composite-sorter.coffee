ConfigNode = require "../config-node"
flip = (sorter)->
  d = sorter.direction()
  sorter.direction switch d
    when 'asc' then 'desc'
    when 'desc' then 'asc'
    else throw new Error "Bad direction: #{d}"

module.exports = class CompositeSorter extends ConfigNode

  constructor: (options)->
    {sorters, direction='asc'} = options
    super options
    @_sorters = sorters
    @_direction = direction
  
  direction: (string)-> 
    if string? then new CompositeSorter sorters:@_sorters, direction:string else @_direction

  sort: ()->
    @_sorters
      .map (s)=> if @_direction is 'desc' then flip(s).sort() else s.sort()
      .reduce ((a,b)->a.concat b), []
