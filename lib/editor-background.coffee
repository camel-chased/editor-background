{CompositeDisposable} = require 'atom'

qr = (selector) -> document.querySelector selector
style = (element) -> document.defaultView.getComputedStyle element
inline = (element,style) -> element.style.cssText += style

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
      default:'100'
      description:"Background image visibility percent 1-100"
      order:5
    treeViewOpacity:
      type:'integer'
      default:"35"
      description:"Tree View can be transparent too :)"
      order:6
    transparentTabBar:
      type:"boolean"
      default:true
      desctiption:"Transparent background under file tabs"
      order:7
    textShadow:
      type:"string"
      default:"0px 5px 2px rgba(0, 0, 0, 0.52)"
      description:"Add a little text shadow to code"
      order:8
    style:
      type:"string"
      default:"background:radial-gradient(rgba(0,0,0,0) 30%,rgba(0,0,0,0.75));"
      description:"Your custom css rules :]"
      order:9

  packagesLoaded:false
  initialized:false
  elements: {}
  colors: {}
  state: {}

  activate: (state) ->
    atom.config.observe 'editor-background',
     (conf) => @applyBackground.apply @,[conf]
    @initialize()

  appendCss: () ->
    css = ""
    cssstyle = document.createElement 'style'
    cssstyle.type = 'text/css'
    cssstyle.setAttribute 'id','#editor-background-css'
    @elements.body.insertBefore cssstyle,@elements.body.childNodes[0]
    @elements.css = cssstyle

  initialize: ->
    @elements.body = qr 'body'
    @elements.workspace = qr 'atom-workspace'
    @elements.editor = atom.workspaceView.panes.find('atom-text-editor')[0]
    @elements.treeView = qr '.tree-view'
    @elements.left = qr '.left'
    @elements.leftPanel = qr '.panel-left'
    @elements.resizer = qr '.tree-view-resizer'
    @elements.tabBar = qr '.tab-bar'
    @elements.insetPanel = qr '.inset-panel'

    keys = Object.keys @elements
    loaded = (@elements[k] for k in keys when @elements[k]?)

    if loaded.length == keys.length
      @elements.plane = document.createElement('div')
      @elements.plane.style.cssText = planeInitialCss
      @elements.body.insertBefore @elements.plane,@elements.body.childNodes[0]
      @appendCss()
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
      inline @elements.body,'background-image:'+bgImage+' !important;'

      if conf.textShadow
        @elements.css.innerText="atom-text-editor::shadow .line{text-shadow:"+conf.textShadow+" !important;}"

      if conf.backgroundSize!='original'
        inline @elements.body, 'background-size:'+conf.backgroundSize+' !important;'
      else
        inline @elements.body, 'background-size:auto !important'
      if conf.manualBackgroundSize
        inline @elements.body, 'background-size:'+conf.manualBackgroundSize+' !important;'

      if conf.style
        @elements.plane.style.cssText+=conf.style

      if conf.transparentTabBar
        inline @elements.tabBar,'background:rgba(0,0,0,0) !important;'
        inline @elements.insetPanel,'background:rgba(0,0,0,0) !important;'

      inline @elements.workspace,'background:'+newColor+' !important;'

      if conf.treeViewOpacity > 0
        inline @elements.treeView,'background:'+newTreeRGBA+' !important;'
        inline @elements.left,'background:transparent !important;'
        inline @elements.resizer,'background:transparent !important;'
        inline @elements.leftPanel,'background:transparent !important;'
