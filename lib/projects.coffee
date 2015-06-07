Project = require './project'
path = require 'path'
fs = require 'fs'
{Emitter} = require 'atom'
{$} = require 'atom-space-pen-views'

module.exports =
  class Projects
    filename: null
    data: {}
    writing: false

    constructor: (arg) ->
      if arg?
        @filename = if arg is '' then null else arg
      else
        @getFileName()
      if @filename?
        @touchFile()
        @getData()
        @watcher = fs.watch @filename, @reload
      else
        @data = {}
      @emitter = new Emitter

    destroy: ->
      @watcher?.close()
      @emitter.dispose()
      @data = {}

    reload: (event,filename) =>
      if not @writing
        @getData() if @filename?
        @emitter.emit 'file-change'
      else
        @writing = false

    getFileName: ->
      @filename = path.join(path.dirname(atom.config.getUserConfigPath()),"build-tools-cpp.projects")

    onFileChange: (callback) ->
      @emitter.on 'file-change', callback

    getData: ->
      CSON = require 'season'
      data = CSON.readFileSync @filename
      Object.keys(data).forEach (key) =>
        @data[key] = new Project(key, data[key], @setData, @checkDependencies)

    setData: =>
      if @filename?
        CSON = require 'season'
        try
          @writing = true
          CSON.writeFileSync @filename, @data
          @emitter.emit 'file-change'
        catch error
          @notify "Settings could not be written to #{@filename}"

    notify: (message) ->
      atom.notifications?.addError message
      console.log('build-tools-cpp: ' + message)

    checkDependencies: ({added, removed, replaced}) =>
      if removed?
        if removed['from']?
          #Removed dependency
          project = @data[removed.to.project]
          command = project.getCommand removed.to.command
          for target,i in command.targetOf
            if (removed.from.project is target.project) and (removed.from.command is target.command)
              command.targetOf.splice(i,1)
              break
        else
          #Removed command
          for target in removed.targetOf
            project = @data[target.project]
            project.dependencies = project.dependencies.filter (value) =>
              not ((value.from.project is target.project) and (value.from.command is target.command))
          project = @data[removed.project]
          omit = []
          project.dependencies = project.dependencies.filter (value) =>
            omit.push(value) if (res = (value.from.command is removed.name))
            not res
          for dep in omit
            @checkDependencies(removed: dep)
      if added?
        #Add dependency
        @data[added.to.project].getCommand(added.to.command).targetOf.push($.extend({}, added.from))
      if replaced?
        #Replaced command
        replaced.new['targetOf'] = replaced.old.targetOf
        for target in replaced.old.targetOf
          project = @data[target.project]
          project.dependencies.forEach (value,index) ->
            if (value.from.project is target.project) and (value.from.command is target.command)
              project.dependencies[index].to.command = replaced.new.name
        project = @data[replaced.old.project]
        project.dependencies.forEach (value,index) ->
          if (value.from.command is replaced.old.name)
            project.dependencies[index].from.command = replaced.new.name



    touchFile: ->
      if not fs.existsSync @filename
        fs.writeFileSync @filename, '{}'

    addProject: (path) ->
      if @data[path]?
        @notify "Project \"#{path}\" already exists"
      else
        @data[path] = new Project(path, {commands: [], dependencies: []}, @setData, @checkDependencies)
        @setData()

    removeProject: (path) ->
      if @data[path]?
        delete @data[path]
        @setData()
      else
        @notify "Project \"#{path}\" not found"

    getNextProjectPath: (file) ->
      p = file.split(path.sep)
      i = p.length
      while (i isnt 0) and (@data[p.slice(0,i).join(path.sep)] is undefined)
        i=i-1
      p.slice(0,i).join(path.sep)

    getProject: (path) ->
      @data[path]

    getProjects: ->
      p = []
      Object.keys(@data).forEach (key) ->
        p.push(key)
      p
