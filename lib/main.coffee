Input = require './provider/input'
Command = require './provider/command'
Project = require './provider/project'

LinterList = null
[ProfileModules, OutputModules, ModifierModules, ProviderModules, StreamModifierModules, EnvironmentModules] = []

{CompositeDisposable} = require 'atom'

CommandEditPane = null
SettingsView = null

path = null

module.exports =

  subscriptions: null

  activate: (state) ->
    Input.activate()
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
      'build-tools:third-command': -> Input.key(2)
      'build-tools:second-command': -> Input.key(1)
      'build-tools:first-command': -> Input.key(0)
      'build-tools:third-command-ask': -> Input.keyAsk(2)
      'build-tools:second-command-ask': -> Input.keyAsk(1)
      'build-tools:first-command-ask': -> Input.keyAsk(0)
      'build-tools:commands': -> Input.selection()
      'core:cancel': -> Input.cancel()
    @subscriptions.add atom.views.addViewProvider Command, (command) ->
      command.oldname = command.name
      CommandEditPane ?= require './view/command-edit-pane'
      new CommandEditPane(command)
    @subscriptions.add atom.workspace.addOpener (uritoopen) ->
      if uritoopen.endsWith '.build-tools.cson'
        path ?= require 'path'
        SettingsView ?= require './view/settings-view'
        new SettingsView(path.dirname(uritoopen), uritoopen)

  deactivate: ->
    @subscriptions.dispose()
    (ModifierModules ? require './modifier/modifier').reset()
    (ProviderModules ? require './provider/provider').reset()
    (StreamModifierModules ? require './stream-modifiers/modifiers').reset()
    (OutputModules ? require './output/output').reset()
    (EnvironmentModules ? require './environment/environment').reset()
    Input.deactivate()
    ModifierModules = null
    ProviderModules = null
    StreamModifierModules = null
    EnvironmentModules = null
    OutputModules = null
    CommandEditPane = null
    SettingsView = null

  provideLinter: ->
    name: 'build-tools-legacy'
    grammarScopes: ['*']
    scope: 'project'
    lintOnFly: false
    lint: ->
      LinterList ?= require './linter-list'
      return [] if LinterList.v1disabled
      LinterList.messages

  consumeLinter: (registerIndie) ->
    LinterList ?= require './linter-list'
    LinterList.linter = registerIndie name: 'build-tools'
    LinterList.v1disabled = true
    @subscriptions.add LinterList.linter
    @subscriptions.add LinterList.linter.onDidDestroy ->
      LinterList.v1disabled = false
      LinterList.linter = null

  provideInput: ->
    ModifierModules ?= require './modifier/modifier'
    ProfileModules ?= require './profiles/profiles'
    ProviderModules ?= require './provider/provider'
    StreamModifierModules ?= require './stream-modifiers/modifiers'
    EnvironmentModules ?= require './environment/environment'
    OutputModules ?= require './output/output'
    {Input, ModifierModules, ProfileModules, ProviderModules, StreamModifierModules, OutputModules, EnvironmentModules}

  provideConsole: ->
    (OutputModules ?= require './output/output').activate 'console'
    OutputModules.modules.console.provideConsole()

  consumeModifierModule: ({key, mod}) ->
    ModifierModules ?= require './modifier/modifier'
    ModifierModules.addModule key, mod

  consumeProfileModuleV1: ({key, profile}) ->
    ProfileModules ?= require './profiles/profiles'
    ProfileModules.addProfile key, profile

  consumeProfileModuleV2: ({key, profile}) ->
    ProfileModules ?= require './profiles/profiles'
    ProfileModules.addProfile key, profile, 2

  consumeProfileModuleV3: (profiles) ->
    ProfileModules ?= require './profiles/profiles'
    disp = new CompositeDisposable
    disp.add(ProfileModules.addProfile(key, profile, 2)) for key, profile of profiles
    disp

  consumeProviderModule: ({key, mod}) ->
    ProviderModules ?= require './provider/provider'
    ProviderModules.addModule key, mod

  consumeEnvironmentModule: ({key, mod}) ->
    EnvironmentModules ?= require './environment/environment'
    EnvironmentModules.addModule key, mod

  consumeStreamModifier: ({key, mod}) ->
    StreamModifierModules ?= require './stream-modifiers/modifiers'
    StreamModifierModules.addModule key, mod

  consumeOutputModule: ({key, mod}) ->
    OutputModules ?= require './output/output'
    OutputModules.addModule key, mod

  config:
    CloseOnSuccess:
      title: 'Close console on success'
      description: 'Value is used in command settings. 0 to hide console on success, >0 to hide console after x seconds'
      type: 'integer'
      default: 3
