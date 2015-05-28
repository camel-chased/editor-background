{CompositeDisposable} = require 'atom'
fs = require 'fs'
blur = require './StackBlur.js'
animation = require './animation'
yt = require './youtube'


qr = (selector) -> document.querySelector selector
style = (element) -> document.defaultView.getComputedStyle element
inline = (element,style) -> element.style.cssText += style
escapeHTML = (text) ->
  text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;")

blobToBase64 = (blob, cb) ->
  reader = new FileReader()
  reader.onload = ->
    dataUrl = reader.result
    base64 = dataUrl.split(',')[1]
    cb(base64)
  reader.readAsDataURL(blob)




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
    youTubeURL:
      type:'string'
      default:''
      order:1
      description:"WARNING!!! NOT FINISHED YET - WORK IN PROGRESS,
      but if you are really curious try to find 'background loop' in YT"
    animationSpeed:
      type:"integer"
      default:100
      order:2
      description:"animation speed in ms, LOWER VALUE = HIGHER CPU USAGE"
    startTime:
      type:"string"
      default:'0s'
      order:3
      description:"video start time like 1h30m10s"
    endTime:
      type:"string"
      default:"20s"
      description:"video end time like 1h30m30s"
      order:4
    textBackground:
      type:"color"
      default:"rgb(0,0,0)"
      order:5
      description:"background color for text/code"
    textBackgroundOpacity:
      type:"integer"
      default:100
      order:6
    textBackgroundBlurRadius:
      type:"integer"
      default:20
      order:7
    backgroundSize:
      type:"string"
      default:"original"
      enum:["original","100%","cover","manual"]
      description:"Background size"
      order:8
    manualBackgroundSize:
      type:"string"
      default:""
      description:"'100px 100px' or '50%' try something..."
      order:9
    customOverlayColor:
      type:"boolean"
      default:false
      order:10
      description:"Do you want different color on top of background? check this"
    overlayColor:
      type:'color'
      default:'rgba(0,0,0,0)'
      description:"Color used to overlay background image"
      order:11
    opacity:
      type:'integer'
      default:'100'
      description:"Background image visibility percent 1-100"
      order:12
    treeViewOpacity:
      type:'integer'
      default:"35"
      description:"Tree View can be transparent too :)"
      order:13
    transparentTabBar:
      type:"boolean"
      default:true
      desctiption:"Transparent background under file tabs"
      order:14
    mouseFactor:
      type:"integer"
      default: 0
      description: "move background with mouse (higher value = slower)
      try 8 or 4 for 3dbox or 20 for wallpaper"
      order:15
    textShadow:
      type:"string"
      default:"0px 2px 2px rgba(0,0,0,0.3)"
      description:"Add a little text shadow to code"
      order:16
    style:
      type:"string"
      default:"background:radial-gradient(rgba(0,0,0,0) 30%,rgba(0,0,0,0.75));"
      description:"Your custom css rules :]"
      order:17
    boxDepth:
      type:"integer"
      default: 0
      minimum: 0
      maximum: 2000
      description:"This is pseudo 3D Cube. Try 500 or 1500 or
      something similar..."
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


  activate: (state) ->
    atom.config.observe 'editor-background',
     (conf) => @applyBackground.apply @,[conf]
    atom.config.observe 'editor-background.imageURL',(url)=>
      @blurImage.apply @,[url]
    atom.config.observe 'editor-background.youTubeURL',(url) =>
      @startYouTube.apply @,[url]
    @initialize()

  appendCss: () ->
    css = ""
    cssstyle = document.createElement 'style'
    cssstyle.type = 'text/css'
    cssstyle.setAttribute 'id','#editor-background-css'
    @elements.main.appendChild cssstyle
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

      boxStyle = document.createElement 'style'
      boxStyle.type = "text/css"
      @elements.main.appendChild boxStyle

      @elements.main.appendChild wrapper
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

  insertMain:->
    main = document.createElement 'div'
    main.id='editor-background-main'
    @elements.main=main
    document.querySelector '#editor-background-main'.remove
    @elements.body.insertBefore main,@elements.body.firstChild
    @elements.modalElement = modal =document.createElement 'div'
    modal.innerText='editor-background loading...'
    @elements.modal = atom.workspace.addModalPanel  {item:modal,visible:false}

  insertTextBackgroundCss:->
    # CSS for background text
    txtBgCss = document.createElement 'style'
    txtBgCss.type="text/css"
    txtBgCss.cssText="
      .editor-background-line{
        background:black;
        color:white;
      }
    "
    @elements.textBackgroundCss=txtBgCss
    @elements.main.appendChild txtBgCss

  insertTextBackground:->
    # container of the background text
    txtBg = document.createElement 'div'
    txtBg.style.cssText="
      position:absolute;
      z-index:-1;
    "
    @elements.textBackground = txtBg
    @elements.main.appendChild txtBg

  getYTId: (url) ->
    if url!=''
      ytreg = /// (?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)
      |youtu\.be\/)([^"&?\/ ]{11}) ///i
      ytidregres=ytreg.exec(url)
      if ytidregres?.length>0
        ytid=ytidregres[1]

  timer:{}
  frames:[]
  frame:0
  videoWidth:0
  videoHeight:0
  playing:true

  getFrame:(canvas,ctx,video,w,h)->
    @frame++
    tick=50
    console.log 'getFrame time',@time
    if @frame*tick >= @time.end - @time.start
      return @getImagesDone
    frame=@elements.main.querySelector '#editor-background-frame'
    frame.innerText=@frame
    ctx.drawImage video,0,0
    video.pause()
    if @playing
      @frames.push canvas.toDataURL('image/jpeg')
      video.play()
      if @playing
        setTimeout =>
          @getFrame.apply @,[canvas,ctx,video,w,h]
        ,tick


  getImages: ->
    @playing=true
    @frame = 0
    console.log 'getting images...'
    video = @elements.video
    canvas = @elements.videoCanvas
    context = canvas.getContext("2d")
    ytid = @getYTId atom.config.get 'editor-background.youTubeURL'

    html="
    <div id='editor-background-modal' style='overflow:hidden'>
    Getting Frame: <span id='editor-background-frame'>0</span><br>
    Please be patient.<br><br>
    <button id='editor-background-done'>
    Cancel</button></div>"
    @showPopup html
    doneBtn = document.querySelector '#editor-background-done'
    doneBtn.addEventListener 'click',=>@getImagesDone()
    w = @videoWidth
    h = @videoHeight
    @getFrame canvas,context,video,w,h

  getImagesDone:->
    @playing=false
    ytid = @elements.ytid

    imagesFolder = @elements.videoPath+ytid+'_images/'
    try
      fs.mkdirSync imagesFolder,0o777
    catch error
      console.log error
    i = 0
    for frame in @frames
      base64 = frame.replace(/^data:image\/jpeg;base64,/, "")
      try
        fs.writeFileSync imagesFolder+i+'.jpg',base64,'base64'
      catch
        console.log error
      i++
    @elements.videoCanvas.remove()
    @elements.video.remove()
    atom.config.set('editor-background.blurRadius',0)
    atom.config.set('editor-background.imageURL','')
    @hidePopup()
    @initAnimation ytid


  decodeVideo:->
    console.log 'decoding video',@elements.video
    @frames = []
    video = @elements.video
    video.addEventListener 'ended',=>
      @getImagesDone()
    video.addEventListener 'canplay',=>
      @getImages()


  insertVideo: (savePath) ->
    data = fs.readFileSync savePath
    videoCanvas = document.createElement 'canvas'
    videoWidth = @videoWidth
    videoHeight = @videoHeight
    videoCanvas.width = videoWidth
    videoCanvas.height = videoHeight
    videoCanvas.id = "editor-background-videoCanvas"
    videoCanvas.style.cssText = "
    position:absolute;
    top:0px;
    left:0px;
    display:none;
    width:#{videoWidth}px;
    height:#{videoHeight}px;
    "
    @elements.videoCanvas = videoCanvas
    @elements.main.insertBefore videoCanvas,@elements.textBackground
    @decodeVideo()

  createVideoElement:(src)->
    video = document.createElement 'video'
    source = document.createElement 'source'
    @elements.video =  video
    @elements.source = source
    video.appendChild source
    source.type="video/"+@elements.videoFormat
    source.src=src
    video.style.cssText="
    position:absolute;
    left:0;
    top:0;
    width:100%;
    height:100%;
    "
    @elements.main.insertBefore video,@elements.textBackground

  createPopup:->
    html = '<div id="editor-background-popup-wrapper">
    <div style="font-size: 1.2em;
      text-align: center;
      margin-bottom: 30px;
      color: white;
      margin: 0px -40px 33px;
      background: black;
      line-height: 32px;">editor-background</div>
      <div id="editor-background-popup-content">
      </div>
      </div>'
    @editorPopup = document.createElement 'div'
    @editorPopup.id = 'editor-background-popup'
    @editorPopup.innerHTML = html
    @editorPopup.style.cssText='
      display:none;
      position:absolute;
      width:300px;
      height:200px;
      left:calc(50% - 150px);
      top: calc(50% - 100px);
      box-sizing:border-box;
      padding:0px 40px 40px;
      background:white;
      color:black;
      z-index:999;
      text-align:center;
    '
    @elements.main.appendChild @editorPopup

  showPopup:(innerHTML)->
    content = document.querySelector '#editor-background-popup-content'
    content.innerHTML = innerHTML
    @editorPopup.style.display='block'

  hidePopup:->
    @editorPopup.style.display='none'

  chooseFormat:(formats,next)->
    html = '
    <div style="font-size:1.1em;text-align:center;margin-bottom:20px;">Choose video format</div>
    <div style="text-align:center;margin-bottom:30px;">
    <select id="background-format" name="format">'
    console.log 'formatChooser'
    formatKeys = Object.keys(formats)
    for itag in formatKeys
      format = formats[itag]
      console.log 'format',format
      html += "<option value=\"#{format.itag}\">Size: #{format.size}</option>"
    html += '</select></div>
    <div style="text-align:center;"><button id="choose-format-btn">Download</button></div>
    </div>'

    @showPopup html

    button = document.querySelector '#choose-format-btn'
    button.addEventListener 'click',(ev)=>
      bgf = document.querySelector '#background-format'
      itag = bgf.value
      @hidePopup()
      next(itag)


  downloadYTVideo: (url)->
    videoExt = @elements.videoExt
    videoFormat = @elements.videoFormat
    if url != ''
      ytid = @getYTId url
      @elements.ytid = ytid
      savePath = @elements.videoPath+ytid+videoExt

      alreadyExists = false
      try
        downloaded = fs.statSync(savePath)
        alreadyExists = downloaded.isFile()
      catch error
        console.log error

      try
        dirExists = fs.statSync @elements.videoPath
        if dirExists?
          if not dirExists.isDirectory()
            fs.mkdirSync @elements.videoPath,0o777
        else
          fs.mkdirSync @elements.videoPath,0o777
      catch e
        console.log e.stack

      if not alreadyExists
        @yt = new yt(url)
        @yt.on 'formats',(formats)=>
          console.log 'formats',formats
        @yt.on 'data',(data)=>
          html='<div style="text-align:center;font-size:1.1em;">
          Downloading: '+data.percent+' %
          </div>'
          @showPopup html

        @yt.on 'done',(chunks)=>
          console.log 'download complete'
          @elements.modalElement.innerHTML="Rendering frames..."
          @createVideoElement(savePath)
          @insertVideo.apply @,[savePath]

        @yt.on 'ready',=>
          conf = atom.config.get('editor-background')
          @time = {
            start:conf.startTime,
            end:conf.endTime
          }
          @chooseFormat @yt.formats,(format)=>
            @videoWidth = @yt.formats[format].width
            @videoHeight = @yt.formats[format].height
            @yt.download {filename:savePath,itag:format,time:@time}

        @yt.getVideoInfo()
      else
        @initAnimation(ytid)
    else
      @removeVideo()


  removeVideo:->
    if @elements.gif?
      @elements.gif.remove()

  startYouTube: ->
    if @packagesLoaded
      @removeVideo()
      conf = atom.config.get 'editor-background'
      if conf.youTubeURL? != ''
        @downloadYTVideo conf.youTubeURL
      else
        @removeVideo()
    else
      setTimeout (=>@startYouTube.apply @,[]),1000


  initAnimation:(ytid)->
    console.log 'initializing Animation...'
    @animation = new animation(ytid)
    @animation.start @elements.main,@elements.textBackground



  getOffset: (element, offset) ->
    {left:0,top:0}
    if element?
      if !offset? then offset = {left:0,top:0}
      offset.left += element.offsetLeft
      offset.top += element.offsetTop
      if element.offsetParent?
        @getOffset element.offsetParent, offset
      else
        offset


  drawLine: (tokenizedLine,attrs) ->
    line = document.createElement 'div'
    line.className = 'editor-background-line'
    text = tokenizedLine.text.trim()
    text = escapeHTML(text)
    text = text.replace(/[\s]{1}/gi,
      '<span class="editor-background-white"></span>')
    text = text.replace(/[\t]{1}/gi,
      '<span class="editor-background-tab"></span>')
    line.innerHTML = text
    marginLeft = tokenizedLine.indentLevel *
      tokenizedLine.tabLength * attrs.charWidth
    marginLeft -= attrs.scrollLeft
    line.style.cssText = "
      margin-left:#{marginLeft}px;
    "
    @elements.textBackground.appendChild line

  drawLines: (attrs) ->
    if attrs?
      if attrs.editorElement? && attrs.screenLines?
        @elements.textBackground.innerText = ''
        editor = attrs.editorElement
        if editor.constructor.name == 'atom-text-editor'

          conf = atom.config.get('editor-background')
          textBlur = conf.textBackgroundBlurRadius
          opacity = (conf.textBackgroundOpacity/100).toFixed(2)
          color = conf.textBackground.toRGBAString()

          root = editor.shadowRoot
          scrollView = root.querySelector '.scroll-view'
          offset = @getOffset scrollView
          top = offset.top - attrs.offsetTop
          left = offset.left
          right = left + scrollView.width + textBlur
          bottom = top + scrollView.height
          activeEditor = attrs.activeEditor
          displayBuffer = attrs.displayBuffer
          lineHeight = attrs.lineHeight
          charWidth = displayBuffer.getDefaultCharWidth()
          tabWidth = displayBuffer.getTabLength() * charWidth

          workspace = qr 'atom-text-editor'
          computedStyle = window.getComputedStyle(workspace)

          fontFamily = computedStyle.fontFamily
          fontSize = computedStyle.fontSize
          if atom.config.settings.editor?
            editorSetting = atom.config.settings.editor
            if editorSetting.fontFamily?
              fontFamily = editorSetting.fontFamily
            if editorSetting.fontSize?
              fontSize = editorSetting.fontSize

          if !/[0-9]+px$/.test(fontSize)
            fontSize+='px'

          css = @elements.textBackgroundCss

          css.innerText="
            .editor-background-line{
              font-family:#{fontFamily};
              font-size:#{fontSize};
              height:#{lineHeight}px;
              display:block;
              color:transparent;
              background:#{color};
              width:auto;
              transform:translate3d(0,0,0);
              float:left;
              clear:both;
            }
            .editor-background-white{
              width:#{charWidth}px;
              display:inline-block;
            }
            .editor-background-tab{
              width:#{tabWidth}px;
              display:inline-block;
            }
          "
          @elements.textBackground.style.cssText="
          top:#{top}px;
          left:#{left}px;
          right:#{right}px;
          bottom:#{bottom}px;
          position:absolute;
          overflow:hidden;
          z-index:0;
          pointer-events:none;
          opacity:#{opacity};
          transform:translate3d(0,0,0);
          -webkit-filter:blur(#{textBlur}px);
          "
          attrsForward = {
            charWidth:charWidth
            scrollLeft:attrs.scrollLeft
          }
          for line in attrs.screenLines
            @drawLine line,attrsForward


  activeEditor:{}

  removeBgLines:->
    @elements.textBackground.innerText=''

  drawBackground: (event,editor)->
    # no editors left
    if event?.destroy?
      if event.destroy.pane.items.length==0
        @removeBgLines()
        return
    # changed active editor
    if event?.active?
      @activeEditor=editor
      if editor?
        process.nextTick =>@drawBackground.apply @,[]
      else
        @removeBgLines()
      return
    activeEditor = @activeEditor
    displayBuffer = activeEditor.displayBuffer
    if displayBuffer?
      actualLines = displayBuffer.getVisibleRowRange()
      screenLines = displayBuffer.buildScreenLines actualLines[0],actualLines[1]
      scrollTop = displayBuffer.getScrollTop()
      scrollLeft = displayBuffer.getScrollLeft()
      lineHeight = displayBuffer.getLineHeightInPixels()
      offsetTop = scrollTop - Math.floor(scrollTop / lineHeight) * lineHeight
      editorElement = atom.views.getView(activeEditor)
      if editorElement?
        if editorElement.constructor.name == 'atom-text-editor'
          editorRect = editorElement.getBoundingClientRect()
          attrs =
            {
              editorElement:editorElement
              activeEditor:activeEditor
              lineHeight:lineHeight
              displayBuffer:displayBuffer
              screenLines:screenLines.screenLines
              offsetTop:offsetTop
              scrollTop:scrollTop
              scrollLeft:scrollLeft
              visibleBuffer: actualLines
            }
          @drawLines attrs

  watchEditor:(editor)->
    editor.onDidChangeScrollTop (scroll)=>
      @drawBackground.apply @,[{scrollTop:scroll},editor]
    editor.onDidChangeScrollLeft (scroll)=>
      @drawBackground.apply @,[{scrolLeft:scroll},editor]
    editor.onDidChange (change)=>
      @drawBackground.apply @,[{change:change},editor]


  watchEditors: ->
    atom.workspace.observeTextEditors (editor)=>
      @watchEditor.apply @,[editor]
    atom.workspace.observeActivePaneItem (editor)=>
      @drawBackground.apply @,[{active:editor},editor]
    atom.workspace.onDidDestroyPaneItem (pane)=>
      @drawBackground.apply @,[{destroy:pane}]

  initialize: ->
    @elements.body = qr 'body'
    # @elements.workspace = atom.views.getView(atom.workspace)
    # doesn't work i dont know why
    @elements.workspace = qr 'atom-workspace'
    @elements.editor = null
    if @elements.workspace?
      activeEditor = atom.workspace.getActiveTextEditor()
      @elements.editor = atom.views.getView(activeEditor)
    @elements.treeView = qr '.tree-view'
    @elements.left = qr '.left'
    @elements.leftPanel = qr '.panel-left'
    @elements.resizer = qr '.tree-view-resizer'
    @elements.tabBar = qr '.tab-bar'
    @elements.insetPanel = qr '.inset-panel'

    keys = Object.keys @elements
    loaded = (@elements[k] for k in keys when @elements[k]?)
    console.log 'keys',keys,loaded
    if loaded.length == keys.length

      @insertMain()
      @createPopup()
      @activateMouseMove()

      conf=atom.config.get('editor-background')

      @elements.image = document.createElement 'img'
      @elements.image.id='editor-background-image'
      @elements.image.setAttribute 'src',conf.imageURL

      @elements.blurredImage = conf.imageURL

      @insertTextBackgroundCss()

      if conf.mouseFactor>0 then @activateMouseMove()
      @elements.plane = document.createElement('div')
      @elements.plane.style.cssText = planeInitialCss
      @elements.main.appendChild @elements.plane
      @appendCss()


      @watchEditors()

      @elements.boxStyle = @createBox()
      @elements.bg = document.createElement 'div'
      @elements.bg.style.cssText="position:absolute;width:100%;height:100%;"
      @elements.main.appendChild @elements.bg
      @insertTextBackground()

      @colors.workspaceBgColor=style(@elements.editor).backgroundColor
      @colors.treeOriginalRGB=style(@elements.treeView).backgroundColor
      @packagesLoaded = true

      @blurImage()
      @elements.videoPath=atom.packages.resolvePackagePath('editor-background')+
        '/youtube-videos/'
      @elements.libPath=atom.packages.resolvePackagePath('editor-background')+
      '/lib/'
      @elements.videoExt = '.mp4'
      @elements.videoFormat = 'mp4'
      try
        fs.mkdirSync @elements.videoPath,0o777
      catch error

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
    if @packagesLoaded
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
        filename = atom.packages.resolvePackagePath('editor-background')+
        "/blur.png"
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
    if @packagesLoaded
      # workspaceView = atom.views.getView(atom.workspace)
      # doesn't work :/
      workspaceView = qr 'atom-workspace'
      console.log 'workspaceView',workspaceView
      if workspaceView?
        workspaceView.className += ' editor-background'
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


      if conf.treeViewOpacity > 0
        inline @elements.treeView,'background:'+newTreeRGBA+' !important;'
        inline @elements.left,'background:transparent !important;'
        inline @elements.resizer,'background:transparent !important;'
        inline @elements.leftPanel,'background:transparent !important;'
