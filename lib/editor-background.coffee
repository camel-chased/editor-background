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
  result = str.replace(/[^\d,\.]/g,'')
  result = result.split(',')
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
    mouseFactor:
      type:"integer"
      default: 4
      description: "move background with mouse (higher value = slower)"
      order:8
    textShadow:
      type:"string"
      #default:"0px 5px 2px rgba(0, 0, 0, 0.52)"
      default:"0px 0px 1px rgba(0,0,0,1),0px 0px 3px #000,0px 0px 3px #000"
      description:"Add a little text shadow to code"
      order:9
    style:
      type:"string"
      default:"background:radial-gradient(rgba(0,0,0,0) 30%,rgba(0,0,0,0.75));"
      description:"Your custom css rules :]"
      order:10
    boxDepth:
      type:"integer"
      default: 500
      minimum: 0
      maximum: 2000
    boxOpacity:
      type:"integer"
      default:30
      minimum:0
      maximum:100
      description:"shadow opacity not box itself ;)"
    boxRange:
      type:"integer"
      description:"this is shadow"
      default:300
      minimum:0
      maximum:1000
    blurRadius:
      type:"integer"
      description:"0 = none"
      default:"4"
      minimim:0
      maximum: 80


  packagesLoaded:false
  initialized:false
  elements: {}
  colors: {}
  state: {}
  mouseX:0
  mouseY:0

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

  createBox: (depth) ->
    #body=(qr 'atom-text-editor').shadowRoot.querySelector('.editor--private')
    body = qr 'body'
    jest = qr 'body .eb-box-wrapper'
    if not jest? or jest.length==0
      left = document.createElement 'div'
      top = document.createElement 'div'
      right = document.createElement 'div'
      bottom = document.createElement 'div'
      back = document.createElement 'div'
      wrapper = document.createElement 'div'
      wrapper.appendChild left
      wrapper.appendChild top
      wrapper.appendChild right
      wrapper.appendChild bottom
      wrapper.appendChild back
      wrapper.setAttribute 'class','eb-box-wrapper'
      left.setAttribute 'class','eb-left'
      top.setAttribute 'class','eb-top'
      right.setAttribute 'class','eb-right'
      bottom.setAttribute 'class','eb-bottom'
      back.setAttribute 'class','eb-back'
      body.insertBefore wrapper,body.childNodes[0]
      boxStyle = document.createElement 'style'
      boxStyle.type = "text/css"
      body.insertBefore boxStyle,body.childNodes[0]
    boxStyle

  mouseMove: (ev) ->
    conf=atom.config.get('editor-background')
    @mouseX=ev.pageX
    @mouseY=ev.pageY
    if conf.boxDepth>0 then @updateBox() else @updateBgPos()


  activateMouseMove: ->
    body = document.querySelector 'body'
    body.addEventListener 'mousemove',(ev) =>  @mouseMove.apply @,[ev]


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
      conf=atom.config.get('editor-background')
      if conf.mouseFactor>0 then @activateMouseMove()
      @elements.plane = document.createElement('div')
      @elements.plane.style.cssText = planeInitialCss
      @elements.body.insertBefore @elements.plane,@elements.body.childNodes[0]
      @appendCss()

      @elements.boxStyle = @createBox()

      @elements.bg = document.createElement('div')
      @elements.bg.style.cssText="position:absolute;width:100%;height:100%;"
      @elements.body.insertBefore @elements.bg,@elements.body.childNodes[0]

      @colors.workspaceBgColor=style(@elements.editor).backgroundColor
      @colors.treeOriginalRGB=style(@elements.treeView).backgroundColor
      @packagesLoaded = true
      @applyBackground.apply @
    else
      setTimeout (=>@initialize.apply @),1000

  updateBgPos: ->
    conf = atom.config.get('editor-background')
    body = qr 'body'
    factor = conf.mouseFactor
    polowaX = body.clientWidth // 2
    polowaY = body.clientHeight // 2
    offsetX =  @mouseX - polowaX
    offsetY =  @mouseY - polowaY
    x = (offsetX // factor)
    y = (offsetY // factor)
    inline @elements.bg,"background-position:#{x}px #{y}px !important;"


  updateBox: (depth) ->
    conf=atom.config.get('editor-background')
    if not depth? then depth = conf.boxDepth
    depth2 = depth // 2
    background=conf.imageURL
    opacity=(conf.boxOpacity / 100).toFixed(2)
    range=conf.boxRange
    range2=range // 3
    bgSize=conf.backgroundSize
    if bgSize=='manual' then bgSize=conf.manualBackgroundSize
    if bgSize=='original' then bgSize='auto'
    body = qr 'body'
    factor = conf.mouseFactor
    polowaX = body.clientWidth // 2
    polowaY = body.clientHeight // 2
    offsetX =  @mouseX - polowaX
    offsetY =  @mouseY - polowaY
    x = polowaX + (offsetX // factor)
    y = polowaY + (offsetY // factor)
    boxCss="
    .eb-box-wrapper{
      perspective:1000px;
      perspective-origin:#{x}px #{y}px;
      position:fixed;
      top:0;
      left:0;
      width:100%;
      height:100%;
    }
    .eb-left,.eb-top,.eb-right,.eb-bottom,.eb-back{
      position:fixed;
      transform-origin:50% 50%;
      box-shadow:inset 0px 0px #{range}px rgba(0,0,0,#{opacity}),
                  inset 0px 0px #{range2}px rgba(0,0,0,#{opacity});
      background:url(#{background});
    }
    .eb-left,.eb-right{
      width:#{depth}px;
      height:100%;
    }
    .eb-top,.eb-bottom{
      width:100%;
      height:#{depth}px;
    }
    .eb-left{
      transform: translate3d(-50%,0,0) rotateY(90deg);
      left:0;
    }
    .eb-top{
      transform: translate3d(0,-50%,0) rotateX(90deg);
      top:0;
    }
    .eb-right{
      transform: translate3d(50%,0,0) rotateY(-90deg);
      right:0;
    }
    .eb-bottom{
      transform: translate3d(0,50%,0) rotateX(-90deg);
      bottom:0;
    }
    .eb-back{
      transform: translate3d(0,0,-#{depth2}px);
      background-size:#{bgSize};
      width:100%;
      height:100%;
    }
    "
    @elements.boxStyle.innerText = boxCss
    if depth==0
      @elements.boxStyle.innerText=".eb-box-wrapper{display:none;}"

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
      inline @elements.bg,'background-image:'+bgImage+' !important;'

      if conf.textShadow
        @elements.css.innerText="atom-text-editor::shadow .line{text-shadow:"+
        conf.textShadow+" !important;}"

      if conf.boxDepth>0
        @updateBox conf.boxDepth
      else
        @elements.boxStyle.innerText=".eb-box-wrapper{display:none;}"

      if conf.backgroundSize!='original'
        inline @elements.bg, 'background-size:'+conf.backgroundSize+
        ' !important;'
      else
        inline @elements.bg, 'background-size:auto !important'
      if conf.manualBackgroundSize
        inline @elements.bg, 'background-size:'+conf.manualBackgroundSize+
        ' !important;'

      if conf.style
        @elements.plane.style.cssText+=conf.style

      if conf.transparentTabBar
        inline @elements.tabBar,'background:rgba(0,0,0,0) !important;'
        inline @elements.insetPanel,'background:rgba(0,0,0,0) !important;'

      inline @elements.workspace,'background:'+newColor+' !important;'

      if conf.boxDepth==0
        inline @elements.bg,'-webkit-filter: blur('+conf.blurRadius+'px)'
      else
        inline @elements.bg,'-webkit-filter: blur(0px)'

      if conf.treeViewOpacity > 0
        inline @elements.treeView,'background:'+newTreeRGBA+' !important;'
        inline @elements.left,'background:transparent !important;'
        inline @elements.resizer,'background:transparent !important;'
        inline @elements.leftPanel,'background:transparent !important;'
