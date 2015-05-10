{CompositeDisposable} = require 'atom'
fs = require 'fs'
blur = require './StackBlur.js'


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
    textBackground:
      type:"color"
      default:"rgb(0,0,0)"
      order:1
      description:"background color for text/code"
    textBackgroundOpacity:
      type:"integer"
      default:100
      order:2
      description:"[0-100] look really nice, but it consume a lot of CPU :/ (0 to turn off)"
    textBackgroundBlurRadius:
      type:"integer"
      default:20
      order:3
      description:"higher value = higher CPU usage"
    backgroundSize:
      type:"string"
      default:"original"
      enum:["original","100%","cover","manual"]
      description:"Background size"
      order:4
    manualBackgroundSize:
      type:"string"
      default:""
      description:"'100px 100px' or '50%' try something..."
      order:5
    customOverlayColor:
      type:"boolean"
      default:false
      order:6
      description:"Do you want different color on top of background? check this"
    overlayColor:
      type:'color'
      default:'rgba(0,0,0,0)'
      description:"Color used to overlay background image"
      order:7
    opacity:
      type:'integer'
      default:'100'
      description:"Background image visibility percent 1-100"
      order:8
    treeViewOpacity:
      type:'integer'
      default:"35"
      description:"Tree View can be transparent too :)"
      order:9
    transparentTabBar:
      type:"boolean"
      default:true
      desctiption:"Transparent background under file tabs"
      order:10
    mouseFactor:
      type:"integer"
      default: 0
      description: "move background with mouse (higher value = slower)
      try 8 or 4 for 3dbox or 20 for wallpaper"
      order:11
    textShadow:
      type:"string"
      default:"0px 2px 2px rgba(0,0,0,0.3)"
      description:"Add a little text shadow to code"
      order:12
    style:
      type:"string"
      default:"background:radial-gradient(rgba(0,0,0,0) 30%,rgba(0,0,0,0.75));"
      description:"Your custom css rules :]"
      order:13
    boxDepth:
      type:"integer"
      default: 0
      minimum: 0
      maximum: 2000
      description:"This is pseudo 3D Cube. Try 500 or 1500 or something similar..."
    boxShadowOpacity:
      type:"integer"
      default:30
      minimum:0
      maximum:100
      description:"shadow that exists in every corner of the box"
    blurRadius:
      type:"integer"
      description:"Background image blur. 0 = none"
      default:50
      minimim:0
      maximum: 200


  packagesLoaded:false
  initialized:false
  elements: {}
  colors: {}
  state: {}
  mouseX:0
  mouseY:0
  editorStyles:[]
  editor:{}
  backBuffer:{}
  frontBuffer:{}
  backContext:{}
  frontContext:{}

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
    if conf.mouseFactor > 0
      @mouseX=ev.pageX
      @mouseY=ev.pageY
      if conf.boxDepth>0 then @updateBox() else @updateBgPos()



  activateMouseMove: ->
    body = document.querySelector 'body'
    body.addEventListener 'mousemove',(ev) =>  @mouseMove.apply @,[ev]

  applyConfToEditor:(style) ->
    return
    conf = atom.config.get 'editor-background'
    rgb=colorToArray conf.textBackground.toRGBAString()
    opacity = (conf.textBackgroundOpacity / 100).toFixed(2)
    if opacity > 0
      rgba = rgb[0]+','+rgb[1]+','+rgb[2]+',0.25'
      rgb = rgb[0]+','+rgb[1]+','+rgb[2]
      linesBgCss = "
        .line>span{
          background:rgba(#{rgba});
          position:relative;
        }
        /*
        .line>span:before{
          content:'';
          opacity:#{opacity};
          position:absolute;
          padding:20px;
          top:-10px;
          width:100%;
          height:100%;
          background:rgb(#{rgb});
          border-radius:10px;
          z-index:-1;
        }*/
      "
    else
      linesBgCss=''
    #linesBgCss=''
    style.innerText=linesBgCss

  applyConfToEditors: ->
    @applyConfToEditor style for style in @editorStyles

  drawIsWaiting:false

  drawTextBackground:(event,editor,wait)->
    if editor?
      #console.log 'drawIsWaiting:',@drawIsWaiting
      if @drawIsWaiting==false
        if wait
          @drawIsWaiting=true
          setTimeout (=>@drawTextBackgroundRun.apply @,[event,editor]),500
        else
          @drawTextBackgroundRun event,editor

  calculateRegion: (event,buffer)->
    if @frontBuffer?
      start=event.start
      end=event.end
      range=buffer.getVisibleRowRange()
      if start>=range[0] and end<=range[1]
        height=buffer.getLineHeightInPixels()
        width=@frontBuffer.width
        start_left_top=buffer.pixelPositionForBufferPosition([range[0],0])
        left_top = buffer.pixelPositionForBufferPosition([start,0])
        right_bottom = buffer.pixelPositionForBufferPosition([end,0])
        #console.log left_top.top-right_bottom.top
        x_=0
        y_=left_top.top-start_left_top.top
        w_=width
        h_=right_bottom.top-left_top.top+height
        region = {x_,y_,w_,h_}
        #console.log 'region',region
        region

  drawTextBackgroundRun:(event,editor)->
    @drawIsWaiting=false
    if editor?
      activeEditor=atom.workspaceView.getActiveView()[0]
      if editor.element == activeEditor
        conf = atom.config.get 'editor-background'
        rgb=colorToArray conf.textBackground.toRGBAString()
        opacity = (conf.textBackgroundOpacity / 100).toFixed(2)
        if opacity > 0 and @textBackground?
          textBlur=conf.textBackgroundBlurRadius
          @textBackground.style.webkitFilter="blur(#{textBlur}px)"
          @textBackground.style.display='block'
          rgba = rgb[0]+','+rgb[1]+','+rgb[2]+',0.25'
          rgb = rgb[0]+','+rgb[1]+','+rgb[2]

          view = editor
          editor = editor.editor
          #console.log view
          range = editor.getVisibleRowRange()
          first = range[0]
          last = range[1]
          buff = editor.displayBuffer
          height = editor.getLineHeightInPixels()
          w = editor.getWidth()
          h = (last-first)*height
          if w? and h?
            @setCanvasSize w,h
            eView= atom.workspaceView.getActiveView()
            if eView?
              if eView[0]?
                leftPos = eView[0].getBoundingClientRect().left
                gutterWidth=view.gutter[0].offsetWidth
                leftPos+=gutterWidth-editor.getScrollLeft()
                #console.log 'leftPos',leftPos
                @textBackground.style.left = leftPos+'px'
                firstLine = editor.getFirstVisibleScreenRow()
                firstLineTop = editor.pixelPositionForBufferPosition([firstLine,0]).top
                if view.element.offsetParent?
                  editorTop=view.element.offsetParent.offsetTop
                else
                  editorTop=0
                topPos=firstLineTop - editor.getScrollTop()+editorTop
                #console.log 'topPos',topPos
                @textBackground.style.top = topPos+'px'
            top = 0
            charWidth = editor.getDefaultCharWidth()
            @frontContext.fillStyle="rgba(#{rgb},#{opacity})"
            #console.log 'drawing...'
            x_=0
            y_=0
            w_=w
            h_=h

            if event.change?
              region=@calculateRegion event.change,buff
              if event.change.start>=range[0] and event.change.end<=range[1]
                first=event.change.start
                last=event.change.end
                top=(first-range[0])*height
              if region?
                {x_,y_,w_,h_}=region
                @frontContext.clearRect( 0, y_, w_, h_)
            else
              @frontContext.clearRect( 0, 0, w, h)
            for lineNumber in [first..last]
              line=editor.lineTextForBufferRow(lineNumber)
              if line?
                if line.length>0
                  indent = editor.indentationForBufferRow(lineNumber)
                  offsetLeft=(indent*editor.getTabLength())*charWidth
                  left = buff.pixelPositionForBufferPosition([lineNumber,0]).left+offsetLeft-charWidth
                  right = buff.pixelPositionForBufferPosition([lineNumber,line.length-1]).left+(charWidth*2)
                  @frontContext.fillRect left,top,right-left,height
              top+=height
            #if @frontBuffer?
              #blur.stackBlurCanvasRGBA @frontBuffer,x_,y_,w_,h_,textBlur
        else
            @textBackground.style.display='none'

  watchEditor: (editor) ->
    conf = atom.config.get('editor-background')
    linesBg = document.createElement 'style'
    linesBg.type='text/css'
    root = editor.root[0]
    lines = editor.root[0].querySelector('.lines')
    lines.insertBefore linesBg,lines.firstChild
    @editorStyles.push linesBg
    @applyConfToEditor linesBg
    ed = editor.editor
    @editor.lineHeight = ed.getLineHeightInPixels()
    ed.onDidChange (e)=> @drawTextBackground.apply @,[{change:e},editor,true]
    #ed.onDidStopChanging (e)=> @drawTextBackground.apply @,[e,editor,true]
    ed.onDidChangeScrollTop (e)=> @drawTextBackground.apply @,[{scrollTop:e},editor]
    ed.onDidChangeScrollLeft (e)=> @drawTextBackground.apply @,[{scrollLeft:e},editor]
    if editor?
      if editor.editor?
        atom.workspace.onDidChangeActivePaneItem (e)=> @drawTextBackground.apply @,[{paneItem:e},editor,true]

  watchEditors: ->
    atom.workspaceView.eachEditorView (editor) => @watchEditor.apply @,[editor]


  setCanvasSize: (w,h)->
    if w!=@frontBuffer.width or h!=@frontBuffer.height
      @frontBuffer.style.width  = w + "px"
      @frontBuffer.style.height = h + "px"
      @frontBuffer.width = w
      @frontBuffer.height = h
    @backBuffer.style.width  = w + "px"
    @backBuffer.style.height = h + "px"
    @backBuffer.width = w
    @backBuffer.height = h

  initCanvas: (w,h) ->
    @frontBuffer = document.createElement 'canvas'
    @frontBuffer.style.cssText="-webkit-transform:translate3d(0,0,0);
    transform:translate3d(0,0,0)"
    @backBuffer = document.createElement 'canvas'
    @frontContext = @frontBuffer.getContext("2d")
    @backContext = @backBuffer.getContext("2d")
    @textBackground = document.createElement 'div'
    @textBackground.id = 'editor-background-text'
    blurRadius=atom.config.get('editor-background.textBackgroundBlurRadius')
    @textBackground.style.cssText="
      position:absolute;
      left:70px;
      top:34px;
      -webkit-transform: translate3d(0, 0, 0);
      transform: translate3d(0,0,0);
    "
    @textBackground.appendChild @frontBuffer
    body = document.querySelector 'body'
    atomWorkspace = document.querySelector 'atom-workspace'
    body.insertBefore @textBackground,atomWorkspace

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
      @watchEditors()
      @activateMouseMove()
      @initCanvas()

      conf=atom.config.get('editor-background')

      @elements.image = document.createElement 'img'
      @elements.image.id='editor-background-image'
      @elements.image.setAttribute 'src',conf.imageURL

      @elements.blurredImage = conf.imageURL

      if conf.mouseFactor>0 then @activateMouseMove()
      @elements.plane = document.createElement('div')
      @elements.plane.style.cssText = planeInitialCss
      @elements.body.insertBefore @elements.plane,@elements.body.childNodes[0]
      @appendCss()

      @elements.boxStyle = @createBox()
      @elements.bg = document.createElement 'div'
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
    background=@elements.blurredImage
    opacity=(conf.boxOpacity / 100).toFixed(2)
    range=300
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
      backface-visibility: hidden;
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
      background-image:url('#{background}');
      background-size:#{bgSize};
      backface-visibility: hidden;
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
      transform: translate3d(-50%,0,0) rotateY(-90deg);
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
      transform: translate3d(0,50%,0) rotateX(90deg);
      bottom:0;
    }
    .eb-back{
      transform: translate3d(0,0,-#{depth2}px);
      width:100%;
      height:100%;
    }
    "
    @elements.boxStyle.innerText = boxCss
    if depth==0
      @elements.boxStyle.innerText=".eb-box-wrapper{display:none;}"

  blurImage:->
    conf = atom.config.get('editor-background')
    @elements.image.setAttribute 'src',conf.imageURL
    applyBlur = false
    if conf.blurRadius > 0
      if @elements.image?
        if @elements.image.complete
          applyBlur = true
        else
          setTimeout (=> @blurImage.apply @),1000
    if applyBlur
      imageData = blur.stackBlurImage @elements.image, conf.blurRadius, false
      base64Data = imageData.replace(/^data:image\/png;base64,/, "")
      filename = atom.packages.resolvePackagePath('editor-background')+"/blur.png"
      filename = filename.replace /\\/gi,'/'
      fs.writeFileSync filename, base64Data,{mode:0o777,encoding:'base64'}
      imageData=filename+"?timestamp="+Date.now()
    else
      imageData = conf.imageURL
    @elements.blurredImage = imageData
    if conf.boxDepth > 0
      @updateBox()
    else
      inline @elements.bg,"background-image: url('#{imageData}') !important"

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

      @blurImage()

      @applyConfToEditors()

      if conf.treeViewOpacity > 0
        inline @elements.treeView,'background:'+newTreeRGBA+' !important;'
        inline @elements.left,'background:transparent !important;'
        inline @elements.resizer,'background:transparent !important;'
        inline @elements.leftPanel,'background:transparent !important;'
