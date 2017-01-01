{CompositeDisposable} = require 'atom'
fs = require 'fs'
blur = require './StackBlur.js'
animation = require './animation'
yt = require './youtube'
popup = require './popup'
configWindow = require './config'
path = require 'path'
elementResizeEvent = require 'element-resize-event'

qr = (selector) -> document.querySelector selector
qra = (selector) -> document.querySelectorAll selector
style = (element) -> document.defaultView.getComputedStyle element
inline = (element,style) -> if element?.style
  element.style.cssText += style
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

shadowDomAlert = false

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
  if !str?
    return [0,0,0,0]
  result = str.replace(/[^\d,\.]/g,'')
  result = result.split(',')
  result

module.exports = EditorBackground =
  config:
    useConfigWindow:
      type:'string'
      description:"USE PACKAGE CONFIG WINDOW INSTEAD OF THIS SETTINGS ( CTRL + SHIFT + E ) TO OPEN"
      toolbox:'ignore'
      default:''
      order:0
    image:
      type:'object'
      properties:
        url:
          type:'string'
          toolbox:'file'
          title:'Image URL'
          default:'atom://editor-background/bg.jpg'
          description:"URL of your image. It can be http://...
          or just /home/yourname/image.jpg"
        blurRadius:
          type:'integer'
          description:"Background image blur. 0 = none"
          default:0
          minimim:0
          maximum: 200
        backgroundSize:
          type:"string"
          default:"original"
          enum:["original","100%","cover","manual"]
          description:"Background size"
        manualBackgroundSize:
          type:"string"
          default:""
          description:"'100px 100px' or '50%' try something..."
        backgroundPosition:
          type:"string"
          default:"center"
          description:"Background position"
        repeat:
          type:"string"
          default:"no-repeat"
          enum:["no-repeat","repeat","repeat-x","repeat-y"]
          description:"Background repeat"
        customOverlayColor:
          type:"boolean"
          default:false
          description:"Do you want different color on top of background?"
        overlayColor:
          type:'color'
          default:'rgba(0,0,0,0)'
          description:"Color used to overlay background image"
        opacity:
          type:'integer'
          default:100
          description:"Background image visibility percent 1-100"
          minimum:0
          maximum:100
        style:
          type:"string"
          toolbox:"text"
          default:"background:radial-gradient(rgba(0,0,0,0) 30%,rgba(0,0,0,0.75));"
          description:"Your custom css rules :]"
    text:
      type:'object'
      properties:
        color:
          type:"color"
          default:"rgba(0,0,0,1)"
          description:"background color for text/code"
        opacity:
          type:"integer"
          default:100
          minimum:0
          maximum:100
        blur:
          type:"integer"
          default:5
          minimum:0
          maximum:50
        expand:
          type:"integer"
          default:4
          description:"If you want larger area under text - try 4 or 10"
          minimum:0
          maximum:200
        shadow:
          type:"string"
          default:"none"
          description:"Add a little text shadow to code like
          '0px 2px 2px rgba(0,0,0,0.3)' "
    video:
      type:'object'
      properties:
        youTubeURL:
          type:'string'
          default:''
          description:"Search for 'background loop',
          'background animation' or similar on youtube and paste url here."
        playAnimation:
          type:"boolean"
          default:false
          description:"enable or disable animation"
        animationSpeed:
          type:"integer"
          default:75
          description:"animation speed in ms (original is 50),
          LOWER VALUE = HIGHER CPU USAGE"
        opacity:
          type:"integer"
          default:75
          minimum:0
          maximum:100
          description:"video opacity"
        startTime:
          type:"string"
          default:'0s'
          description:"video start time like 1h30m10s or 10s"
        endTime:
          type:"string"
          default:"20s"
          description:"video end time like 1h30m30s or 30s"
    other:
      type:'object'
      properties:
        treeViewOpacity:
          type:'integer'
          default:"35"
          description:"Tree View can be transparent too :)"
          minimum:0
          maximum:100
        transparentTabBar:
          type:"boolean"
          default:true
          desctiption:"Transparent background under file tabs"
    box3d:
      type:'object'
      properties:
        depth:
          type:"integer"
          default: 0
          minimum: 0
          maximum: 2000
          description:"This is pseudo 3D Cube. Try 500 or 1500 or
          something similar..."
        shadowOpacity:
          type:"integer"
          default:30
          minimum:0
          maximum:100
          description:"shadow that exists in every corner of the box"
        mouseFactor:
          type:"integer"
          default: 0
          description: "move background with mouse (higher value = slower)
          try 8 or 4 for 3dbox or 20 for wallpaper"





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
    @subs = new CompositeDisposable
    @subs.add atom.commands.add 'atom-workspace',
      'editor-background:toggle': => @toggle()
    @subs.add atom.config.observe 'editor-background',
     (conf) => @applyBackground.apply @,[conf]
    @subs.add atom.config.observe 'editor-background.image.url',(url)=>
      @blurImage.apply @,[url]
    @subs.add atom.config.observe 'editor-background.video.youTubeURL',(url) =>
      @startYouTube.apply @,[url]
    @subs.add atom.config.observe 'editor-background.video.playAnimation',(play) =>
        if play==false
            @removeVideo()
        else
            @startYouTube.apply @,[]

    @initializePackage()

  deactivate: ()->
    if @subs?
        @subs.dispose()
    if @elements?.main?
        @elements.main.remove()

  appendCss: () ->
    css = ""
    cssstyle = document.createElement 'style'
    cssstyle.type = 'text/css'
    cssstyle.setAttribute 'id','#editor-background-css'
    @elements.main.appendChild cssstyle
    @elements.css = cssstyle

  createBox: (depth) ->
    body = @elements.body
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
    conf=@configWnd.get('editor-background')
    if conf.box3d.mouseFactor > 0
      @mouseX=ev.pageX
      @mouseY=ev.pageY
      if conf.box3d.depth>0 then @updateBox() else @updateBgPos()



  activateMouseMove: ->
    body = @elements.body
    body.addEventListener 'mousemove',(ev) =>  @mouseMove.apply @,[ev]

  insertMain:->
    main = document.createElement 'div'
    main.id='editor-background-main'
    @elements.main=main
    document.querySelector '#editor-background-main'.remove
    @elements.body.insertBefore main,@elements.body.firstChild
    @elements.itemViews = document.querySelectorAll '.item-views'
    for el in @elements.itemViews
        el.style.cssText="background:transparent !important";

  insertTextBackgroundCss:->
    # CSS for background text
    txtBgCss = document.createElement 'style'
    txtBgCss.type="text/css"
    bgColor =
    txtBgCss.cssText="
      .editor-background-line{
        background:black;
        color:white;
      }
      atom-pane-container atom-pane .item-views{
        background:transparent !important;
        background-color:transparent !important;
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
    #console.log 'getFrame time',@time
    if @frame*tick >= @time.end - @time.start
      return @getImagesDone
    frame=document.querySelector '#editor-background-frame'
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
    #console.log 'getting images...'
    video = @elements.video
    canvas = @elements.videoCanvas
    context = canvas.getContext("2d")
    ytid = @getYTId @configWnd.get 'editor-background.video.youTubeURL'

    html="
    <div id='editor-background-modal' style='overflow:hidden'>
    Getting Frame: <span id='editor-background-frame'>0</span><br>
    Please be patient.</div>"
    title= 'Editor background - frames'
    args = {
      buttons:{
        "Cancel":(ev)=>@getImagesDone()
      },
      title:title,
      content:html
    }
    @popup.show args

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
      #console.log error
    i = 0
    for frame in @frames
      base64 = frame.replace(/^data:image\/jpeg;base64,/, "")
      try
        fs.writeFileSync imagesFolder+i+'.jpg',base64,'base64'
      catch
        #console.log error
      i++
    @elements.videoCanvas.remove()
    @elements.video.remove()
    @removeOldCanvas()
    atom.config.set('editor-background.blurRadius',0)
    atom.config.set('editor-background.imageURL','')
    @popup.hide()
    @initAnimation ytid


  decodeVideo:->
    #console.log 'decoding video',@elements.video
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
    @removeOldCanvas()
    videoCanvas.id = "editor-background-videoCanvas"
    conf = @configWnd.get 'editor-background'
    videoOpacity = (conf.video.opacity/100).toFixed(2)
    videoCanvas.style.cssText = "
    position:absolute;
    top:0px;
    left:0px;
    display:none;
    width:#{videoWidth}px;
    height:#{videoHeight}px;
    opacity:#{videoOpacity};
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



  chooseFormat:(formats,next)->
    #console.log 'choose format?'
    html = '
    <div style="font-size:1.1em;text-align:center;margin-bottom:20px;">
    Choose video format</div>
    <div style="text-align:center;margin-bottom:30px;">
    <select id="background-format" name="format">'
    #console.log 'formatChooser'
    formatKeys = Object.keys(formats)
    for itag in formatKeys
      format = formats[itag]
      #console.log 'format',format
      html += "<option value=\"#{format.itag}\">Size: #{format.size}</option>"
    html += '</select></div>
    </div>
    <br><br>
    </div>'

    args = {
      buttons:{
        "OK":(ev,popup)=>
          bgf = document.querySelector '#background-format'
          itag = bgf.value
          @popup.hide()
          next(itag)
      },
      content:html,
      title:"Editor Background - Video format"
    }
    #console.log 'show popup?'
    @popup.show args



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
        #console.log error

      try
        dirExists = fs.statSync @elements.videoPath
        if dirExists?
          if not dirExists.isDirectory()
            fs.mkdirSync @elements.videoPath,0o777
        else
          fs.mkdirSync @elements.videoPath,0o777
      catch e
        #console.log e.stack

      if not alreadyExists
        @yt = new yt(url)
        @yt.on 'formats',(formats)=>
          #console.log 'formats',formats
        @yt.on 'data',(data)=>
          html='<div style="text-align:center;font-size:1.1em;">
          Downloading: '+(data.percent).toFixed(2)+' %
          </div>'
          title = 'Editor Background - download'
          args = {
            title:"Editor Background - downloading...",
            content:html
          }
          @popup.show args

        @yt.on 'done',(chunks)=>
          @popup.hide()
          @createVideoElement(savePath)
          @insertVideo.apply @,[savePath]

        @yt.on 'ready',=>
          #console.log 'get video info ready'
          conf = @configWnd.get('editor-background')
          @time = {
            start:conf.video.startTime,
            end:conf.video.endTime
          }
          @chooseFormat @yt.formats,(format)=>
            #console.log 'we chosen format',format
            @videoWidth = @yt.formats[format].width
            @videoHeight = @yt.formats[format].height
            @yt.download {filename:savePath,itag:format,time:@time}
        #console.log 'getting video info'
        @yt.getVideoInfo()
      else
        @initAnimation(ytid)
    else
      @removeVideo()

  removeOldCanvas:->
    el = qra "#editor-background-videoCanvas"
    el.forEach (e)->
      console.log("removing",e)
      e.remove()

    el = qra ".editor-background-animation"
    el.forEach (e)->e.remove()

  removeVideo:->
    if @animation?
        @animation.stop()
        delete @animation
    @removeOldCanvas()


  startYouTube: ->
    if @packagesLoaded
      conf = @configWnd.get 'editor-background'
      if conf.video.youTubeURL? != '' && conf.video.playAnimation
        if !@animation?
            @downloadYTVideo conf.video.youTubeURL
      else
        @removeVideo()
    else
      setTimeout (=>@startYouTube.apply @,[]),1000


  initAnimation:(ytid)->
    canvasIsAdded = qra ".editor-background-animation".length>0
    if !@animation?
      atom.notifications.add 'notice','starting animation...'
      @animation = new animation(ytid)
      @animation.start @elements.main,@elements.textBackground
      conf = @configWnd.get 'editor-background'
      videoOpacity = (conf.video.opacity/100).toFixed(2)
      if @animation?.canvas?
          inline @animation.canvas,"opacity:#{videoOpacity};"


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


  drawLine: (textLine,attrs) ->
    line = document.createElement 'div'
    line.className = 'editor-background-line'
    text = textLine.trim()
    text = escapeHTML(text)
    text = text.replace(/[\s]{1}/gi,
      '<span class="editor-background-white"></span>')
    text = text.replace(/[\t]{1}/gi,
      '<span class="editor-background-tab"></span>')
    line.innerHTML = text

    startTextOffset = textLine.search(/[^\s]+/gi)
    startText = textLine.substr(0,startTextOffset)

    spaces = startText.match(/ +/)?[0].length
    if !spaces?
      spaces=0
    tabs = textLine.match(/^\t+/)?[0].length
    if !tabs?
      tabs=0
    offsetLeft = spaces*attrs.charWidth + tabs*attrs.tabWidth

    marginLeft = offsetLeft
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

          conf = @configWnd.get('editor-background')
          #console.log 'conf',conf
          textBlur = conf.text.blur
          opacity = (conf.text.opacity/100).toFixed(2)
          color = conf.text.color.toHexString()
          expand = conf.text.expand

          root = editor.rootElement
          scrollView = root.querySelector '.scroll-view'

          activeEditor = atom.workspace.getActiveTextEditor()
          editor = atom.views.getView(activeEditor)

          #console.log "screen lines",attrs.screenLines

          if scrollView?
            offset = @getOffset scrollView
            top = offset.top - attrs.offsetTop
            left = offset.left
            right = left + scrollView.width + textBlur
            bottom = top + scrollView.height
            activeEditor = attrs.activeEditor
            lineHeight = attrs.lineHeight
            charWidth = activeEditor.getDefaultCharWidth()
            tabWidth = activeEditor.getTabLength() * charWidth



          if editor?
            computedStyle = window.getComputedStyle(editor)

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

            scaleX = 1 + parseFloat((expand / 100).toFixed(2))
            scaleY = 1 + parseFloat((expand / 10).toFixed(2))


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
                border-radius:10px;
                transform:translate3d(0,0,0) scale(#{scaleX},#{scaleY});
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
              tabWidth:tabWidth
              scrollLeft:attrs.scrollLeft
            }
            for line in attrs.screenLines
              @drawLine line,attrsForward if line?


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

    @activeEditor = atom.workspace.getActiveTextEditor()
    if event?.active?
      @activeEditor=editor
      if editor?
        process.nextTick =>@drawBackground.apply @,[]
      else
        @removeBgLines()
      return
    activeEditor = @activeEditor

    if activeEditor?
      buffer = activeEditor.getBuffer()
      editorElement = atom.views.getView(activeEditor)
      actualLines = activeEditor.getVisibleRowRange()
      lines = buffer.getLines()

      if !actualLines?
        @removeBgLines()
        actualLines = [0,1]
        # we must display text bg even if visibleRowRange returns null
        # because there may be some characters that user is typing

      if actualLines?.length == 2
        if actualLines? && actualLines[0]? && actualLines[1]?
          #screenLines = tokenizedLines[ actualLines[0]..actualLines[1] ]
          screenLines = lines[actualLines[0]..actualLines[1]]
          #console.log "screenLines",screenLines
          elem = activeEditor.getElement()

          scrollTop = elem.getScrollTop()
          scrollLeft = elem.getScrollLeft()
          lineHeight = activeEditor.getLineHeightInPixels()
          offsetTop = scrollTop - Math.round(scrollTop / lineHeight) * lineHeight
          editorElement = atom.views.getView(activeEditor)
          if editorElement?
            if editorElement.constructor.name == 'atom-text-editor'
              editorRect = editorElement.getBoundingClientRect()
              attrs =
                {
                  editorElement:editorElement
                  activeEditor:activeEditor
                  lineHeight:lineHeight
                  screenLines:screenLines
                  offsetTop:offsetTop
                  scrollTop:scrollTop
                  scrollLeft:scrollLeft
                  visibleBuffer: actualLines
                }
              @drawLines attrs

  watchEditor:(editor)->
    elem = editor.getElement()
    @subs.add elem.onDidChangeScrollTop (scroll)=>
      @drawBackground.apply @,[{scrollTop:scroll},editor]
    @subs.add elem.onDidChangeScrollLeft (scroll)=>
      @drawBackground.apply @,[{scrolLeft:scroll},editor]
    @subs.add editor.onDidChange (change)=>
      @drawBackground.apply @,[{change:change},editor]
    element = editor.getElement()
    model = element.getModel()
    editorElement = model.editorElement.component.domNodeValue
    # little hack because of no "resize" event on textEditor
    elementResizeEvent editorElement,()=>
      @drawBackground.apply @,[{resize:editorElement},editor]


  watchEditors: ->
    @subs.add atom.workspace.observeTextEditors (editor) =>
      @editorLoaded()
      @watchEditor.apply @,[editor]
    @subs.add atom.workspace.observeActivePaneItem (editor)=>
      @editorLoaded()
      @drawBackground.apply @,[{active:editor},editor]
    @subs.add atom.workspace.onDidDestroyPaneItem (pane)=>
      @drawBackground.apply @,[{destroy:pane}]
    @subs.add atom.workspace.onDidDestroyPane (pane)=>
      @drawBackground.apply @,[{destroy:pane}]
    # another hack to be notified when new editor comes in place
    @subs.add atom.workspace.emitter.on "did-add-text-editor",(ev)=>
      @editorLoaded()
      editor = ev.textEditor
      @drawBackground.apply @,[{active:editor},editor]
    #@subs.add atom.workspace.onDidInsertText (text)=>

  editorLoaded: ->
    if @elements.workspace?
      activeEditor = atom.workspace.getActiveTextEditor()
      @elements.editor = atom.views.getView(activeEditor)
      if @elements.editor?
        @colors.workspaceBgColor=style(@elements.editor).backgroundColor

  initializePackage: ->
    @elements.body = qr 'body'
    @elements.workspace = qr 'atom-workspace'
    @elements.editor = null
    if @elements.workspace?
      activeEditor = atom.workspace.getActiveTextEditor()
      @elements.editor = atom.views.getView(activeEditor)
    @elements.treeView = qr '.tree-view'
    @elements.left = qr '.left'
    @elements.leftPanel = (qr '.panel-left') or (qr '.panel-right')
    @elements.resizer = qr '.tree-view-resizer'
    @elements.tabBar = qr '.tab-bar'
    @elements.insetPanel = qr '.inset-panel'

    keys = Object.keys @elements
    loaded = (@elements[k] for k in keys when @elements[k]?)
    #console.log 'keys',keys,loaded
    if true

      @insertMain()
      @popup = new popup()
      confOptions = {
        onChange:()=>
          @drawBackground()
      }
      @configWnd = new configWindow 'editor-background',confOptions
      @activateMouseMove()

      conf=@configWnd.get('editor-background')

      @elements.image = document.createElement 'img'
      @elements.image.id='editor-background-image'
      @elements.image.setAttribute 'src',conf.image.url

      @elements.blurredImage = conf.image.url

      @insertTextBackgroundCss()

      if conf.box3d.mouseFactor>0 then @activateMouseMove()

      @appendCss()
      @watchEditors()

      @elements.bg = document.createElement 'div'
      @elements.bg.style.cssText="position:absolute;width:100%;height:100%;"
      @elements.main.appendChild @elements.bg

      @elements.boxStyle = @createBox()

      @elements.plane = document.createElement('div')
      @elements.plane.style.cssText = planeInitialCss
      @elements.main.appendChild @elements.plane

      @insertTextBackground()

      if @elements.editor?
        @colors.workspaceBgColor=style(@elements.editor).backgroundColor
      else
        @colors.workspaceBgColor="rgb(0,0,0)"

      if @elements.treeView?
        @colors.treeOriginalRGB=style(@elements.treeView).backgroundColor
      else
        @colors.treeOriginalRGB="rgb(0,0,0)"

      @packagesLoaded = true

      videoOpacity = (conf.video.opacity/100).toFixed(2)
      if @animation?.canvas?
          inline @animation.canvas,"opacity:#{videoOpacity};";

      @blurImage()


      @elements.videoPath=@pluginPath()+'/youtube-videos/'
      @elements.libPath=@pluginPath()+'/lib/'
      @elements.videoExt = '.mp4'
      @elements.videoFormat = 'mp4'
      try
        fs.mkdirSync @elements.videoPath,0o777
      catch error

      @applyBackground.apply @
    else
      setTimeout (=>@initializePackage.apply @),1000

  updateBgPos: ->
    conf = @configWnd.get('editor-background')
    body = @elements.body
    factor = conf.box3d.mouseFactor
    polowaX = body.clientWidth // 2
    polowaY = body.clientHeight // 2
    offsetX =  @mouseX - polowaX
    offsetY =  @mouseY - polowaY
    x = (offsetX // factor)
    y = (offsetY // factor)
    inline @elements.bg,"background-position:#{x}px #{y}px !important;"

  updateBox: (depth) ->
    conf=@configWnd.get('editor-background')
    if not depth? then depth = conf.box3d.depth
    depth2 = depth // 2
    background=@elements.blurredImage
    opacity=(conf.box3d.shadowOpacity / 100).toFixed(2)
    imgOpacity = conf.image.opacity / 100
    range=300
    range2=range // 3
    bgSize=conf.image.backgroundSize
    if bgSize=='manual' then bgSize=conf.image.manualBackgroundSize
    if bgSize=='original' then bgSize='auto'
    body = @elements.body
    factor = conf.box3d.mouseFactor
    polowaX = body.clientWidth // 2
    polowaY = body.clientHeight // 2
    offsetX =  @mouseX - polowaX
    offsetY =  @mouseY - polowaY
    x = polowaX + (offsetX // factor)
    y = polowaY + (offsetY // factor)
    inline @elements.bg,"opacity:0;"
    position = conf.image.backgroundPosition
    repeat = conf.image.repeat
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
      opacity:#{imgOpacity};
    }
    .eb-left,.eb-top,.eb-right,.eb-bottom,.eb-back{
      position:fixed;
      transform-origin:50% 50%;
      box-shadow:inset 0px 0px #{range}px rgba(0,0,0,#{opacity}),
                  inset 0px 0px #{range2}px rgba(0,0,0,#{opacity});
      background-image:url('#{background}');
      background-size:#{bgSize};
      backface-visibility: hidden;
      background-position:#{position};
      background-repeat:#{repeat};
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

  pluginPath:->
    _path = atom.packages.resolvePackagePath('editor-background')
    if !_path
      _path = path.resolve(__dirname)
    return _path

  blurImage:->
    if @packagesLoaded
      conf = @configWnd.get('editor-background')
      @elements.image.setAttribute 'src',conf.image.url
      applyBlur = false
      if conf.image.blurRadius > 0
        if @elements.image?
          if @elements.image.complete
            applyBlur = true
          else
            setTimeout (=> @blurImage.apply @),1000
      if applyBlur and conf.image.url
        imageData = blur.stackBlurImage @elements.image, conf.image.blurRadius, false
        base64Data = imageData.replace(/^data:image\/png;base64,/, "")
        filename = @pluginPath()+"/blur.png"
        filename = filename.replace /\\/gi,'/'

        fs.writeFileSync filename, base64Data,{mode:0o777,encoding:'base64'}
        imageData=filename+"?timestamp="+Date.now()
      else
        imageData = conf.image.url
      @elements.blurredImage = imageData
      if conf.box3d.depth > 0
        @updateBox()
      else
        opacity = conf.image.opacity / 100
        position = conf.image.backgroundPosition
        repeat = conf.image.repeat
        inline @elements.bg,"background-image: url('#{imageData}') !important;"
        inline @elements.bg,"opacity:#{opacity};"
        inline @elements.bg,"background-position:#{position};"
        inline @elements.bg,"background-repeat:#{repeat};"

  applyBackground: ->
    if @packagesLoaded
      workspaceView = @elements.workspace
      #console.log 'workspaceView',workspaceView
      if workspaceView?
        if workspaceView.className.indexOf('editor-background') == -1
            workspaceView.className += ' editor-background'
      conf = @configWnd.get 'editor-background'
      opacity = 100 - conf.image.opacity
      alpha=(opacity / 100).toFixed(2)

      rgb = colorToArray @colors.workspaceBgColor
      newColor = 'rgba( '+rgb[0]+' , '+rgb[1]+' , '+rgb[2]+' , '+alpha+')'

      treeOpacity = conf.other.treeViewOpacity
      treeAlpha = (treeOpacity / 100).toFixed(2)
      treeRGB = colorToArray @colors.treeOriginalRGB

      newTreeRGBA =
        'rgba('+treeRGB[0]+','+treeRGB[1]+','+treeRGB[2]+','+treeAlpha+')'

      if conf.image.customOverlayColor
        _newColor = conf.image.overlayColor.toRGBAString()
        rgb = colorToArray _newColor
        newColor = 'rgba('+rgb[0]+','+rgb[1]+','+rgb[2]+','+alpha+')'
        newTreeRGBA='rgba('+rgb[0]+','+rgb[1]+','+rgb[2]+','+treeAlpha+')'
      else
        _newColor = @colors.workspaceBgColor
      @elements.css.innerText+="body{background:#{_newColor} !important;}"

      #@elements.css.innerText+="\natom-pane-container atom-pane .item-views{background:transparent !important;}"

      if conf.text.shadow
        @elements.css.innerText+="\natom-text-editor::shadow .line{text-shadow:"+
        conf.text.shadow+" !important;}"

      if conf.box3d.depth>0
        @updateBox conf.box3d.depth
      else
        @elements.boxStyle.innerText=".eb-box-wrapper{display:none;}"

      #console.log 'conf.image.size',conf.image.backgroundSize
      if conf.image.backgroundSize!='original'
        inline @elements.bg, 'background-size:'+conf.image.backgroundSize+
        ' !important;'
      else
        inline @elements.bg, 'background-size:auto !important'
      if conf.image.backgroundSize == 'manual'
        inline @elements.bg, 'background-size:'+conf.image.manualBackgroundSize+
        ' !important;'

      if conf.image.style
        @elements.plane.style.cssText+=conf.image.style

      @blurImage()

      if conf.other.transparentTabBar
        inline @elements.tabBar,'background:rgba(0,0,0,0) !important;'
        inline @elements.insetPanel,'background:rgba(0,0,0,0) !important;'

      if conf.other.treeViewOpacity > 0
        inline @elements.treeView,'background:'+newTreeRGBA+' !important;'
        inline @elements.left,'background:transparent !important;'
        inline @elements.resizer,'background:transparent !important;'
        inline @elements.leftPanel,'background:transparent !important;'






  # show config window
  toggle:->
    if not @configWnd
      atom.notifications.add 'warning','Editor-background is only available after you open some files.'
    else
      if not @configWnd.visible
        @configWnd.show()
      else
        @popup.hide()
