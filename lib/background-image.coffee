BackgroundImageView = require './background-image-view'
{CompositeDisposable} = require 'atom'

module.exports = BackgroundImage =
  subscriptions: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
     'background-image:toggle': => @toggle()

  deactivate: ->
    @subscriptions.dispose()

  toggle: ->
    console.log 'BackgroundImage was toggled!'
    atom.workspaceView.toggleClass 'editor-background'
