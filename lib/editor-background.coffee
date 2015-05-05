{CompositeDisposable} = require 'atom'

qr = (selector) -> document.querySelector selector
style = (element) -> document.defaultView.getComputedStyle element

planeInitialCss =
  "position:absolute;
  left:0;
  top:0;
  width:100%;
  height:100%;
  background:transparent;
  pointer-events:none;
  z-index:0;"

colorToArray = (str) ->
  console.log 'str',str
  result = str.replace(/[^\d,\.]/g,'')
  console.log 'result before',result
  result = result.split(',')
  console.log 'result after',result
  result


module.exports = EditorBackground =
  config:
    imageURL:
      type:'string'
      default:'atom://editor-background/bg.jpg'
      order:0
      description:"URL of your image. It can be http://...
      or just /home/yourname/image.jpg"
    backgroundSize:
      type:"string"
      default:"original"
      enum:["original","100%","cover","manual"]
      description:"Background size"
      order:1
    manualBackgroundSize:
      type:"string"
      default:""
      description:"'100px 100px' or '50%' try something..."
      order:2
    customOverlayColor:
      type:"boolean"
      default:false
      order:3
      description:"Do you want different color on top of background? check this"
    overlayColor:
      type:'color'
      default:'rgba(0,0,0,0)'
      description:"Color used to overlay background image"
      order:4
    opacity:
      type:'integer'
      default:'20'
      description:"Background image visibility percent 1-100"
      order:5
    treeViewOpacity:
      type:'integer'
      default:"25"
      description:"Tree View can be transparent too :)"
      order:6
    style:
      type:"string"
      default:""
      description:"Your custom css rules :]"
      order:7

  packagesLoaded:false
  initialized:false
  elements: {}
  colors: {}
  state: {}

  activate: (state) ->
    atom.config.observe 'editor-background',
     (conf) => @applyBackground.apply @,[conf]
    @initialize()

  initialize: ->
    @elements.body = qr 'body'
    @elements.workspace = qr 'atom-workspace'
    @elements.editor = atom.workspaceView.panes.find('atom-text-editor')[0]
    @elements.treeView = qr '.tree-view'
    @elements.left = qr '.left'
    @elements.leftPanel = qr '.panel-left'
    @elements.resizer = qr '.tree-view-resizer'
    @elements.html = qr 'html'

    keys = Object.keys @elements
    loaded = (@elements[k] for k in keys when @elements[k]?)

    if loaded.length == keys.length
      @elements.plane = document.createElement('div')
      @elements.plane.style.cssText = planeInitialCss
      @elements.body.insertBefore @elements.plane,@elements.body.childNodes[0]

      @colors.workspaceBgColor=style(@elements.editor).backgroundColor
      @colors.treeOriginalRGB=style(@elements.treeView).backgroundColor
      console.log @colors
      @packagesLoaded = true
      @applyBackground.apply @
    else
      setTimeout (=>@initialize.apply @),1000


  deactivate: ->
    @subscriptions.dispose()

  applyBackground: ->
    atom.workspaceView.addClass 'editor-background'
    if @packagesLoaded
      conf = atom.config.get 'editor-background'
      opacity = 100 - conf.opacity
      alpha=(opacity / 100).toFixed(2)

      rgb = colorToArray @colors.workspaceBgColor
      newColor = 'rgba( '+rgb[0]+' , '+rgb[1]+' , '+rgb[2]+' , '+alpha+')'

      treeOpacity = conf.treeViewOpacity
      treeAlpha = (treeOpacity / 100).toFixed(2)
      treeRGB = colorToArray @colors.treeOriginalRGB

      newTreeRGBA =
        'rgba('+treeRGB[0]+','+treeRGB[1]+','+treeRGB[2]+','+treeAlpha+')'

      if conf.customOverlayColor
        newColor = conf.overlayColor.toRGBAString()
        rgb = colorToArray newColor
        newColor = 'rgba('+rgb[0]+','+rgb[1]+','+rgb[2]+','+alpha+')'
        newTreeRGBA='rgba('+rgb[0]+','+rgb[1]+','+rgb[2]+','+treeAlpha+')'

      bgImage = 'url('+conf.imageURL+')'
      @elements.body.style.backgroundImage = bgImage

      if conf.backgroundSize!='original'
        @elements.body.style.backgroundSize=conf.backgroundSize
      if conf.manualBackgroundSize
        @elements.body.style.backgroundSize=conf.manualBackgroundSize

      if conf.style
        @elements.plane.style.cssText+=conf.style

      @elements.workspace.style.background = newColor

      if conf.treeViewOpacity > 0
        @elements.treeView.style.background = newTreeRGBA
        @elements.left.style.background = 'transparent'
        @elements.resizer.style.background = 'transparent'
        @elements.leftPanel.style.background= 'transparent'
