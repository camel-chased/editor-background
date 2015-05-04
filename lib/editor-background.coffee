{CompositeDisposable} = require 'atom'

module.exports = EditorBackground =
  config:
    url:
      type:'string'
      default:'atom://editor-background/bg.jpg'
    opacity:
      type:'integer'
      default:'20'

  subscriptions: null
  bgEnabled: false


  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace',
     'editor-background:toggle': => @toggle()
    atom.config.observe 'editor-background',
     (conf) => @applyBackground.apply @,[conf]


  deactivate: ->
    @subscriptions.dispose()

  applyBackground: ->
    body = document.querySelector('body')
    workspace = document.querySelector('atom-workspace')
    editor = atom.workspaceView.panes.find('atom-text-editor')[0]
    opacity = 100 - atom.config.get('editor-background.opacity')
    alpha=opacity / 100
    workspaceBgColor =
      document.defaultView.getComputedStyle(editor).backgroundColor
    rgb = /rgba?\((\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(,\s*\d+[\.\d+]*)*\)/g
    .exec(workspaceBgColor)
    newColor = 'rgba( '+rgb[1]+' , '+rgb[2]+' , '+rgb[3]+' , '+alpha+')'
    if @bgEnabled
      body.style.backgroundImage =
        'url('+atom.config.get('editor-background.url')+')'
      workspace.style.background = newColor
    else
      body.style.background=''
      workspace.style.background=''



  toggle: ->
    if @bgEnabled then @bgEnabled=false else @bgEnabled=true
    atom.workspaceView.toggleClass 'editor-background'
    @applyBackground()
