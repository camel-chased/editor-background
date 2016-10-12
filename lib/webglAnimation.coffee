fs = require 'fs'

class WebGLAnimation

  ytid:''
  homeDir:''
  videoDir:''
  animPath:''
  frames:[]
  currentFrame:0
  fadeOut:50


  constructor: (ytid) ->
    @loaded = 0
    @playing = false
    @speed = atom.config.get 'editor-background.animationSpeed'
    atom.config.observe 'editor-background.animationSpeed',(speed)=>
      @setSpeed(speed)
    @homeDir = atom.packages.resolvePackagePath('editor-background')
    @videoDir = @homeDir + '/youtube-videos'
    if ytid?
      @ytid = ytid
    else
      url = atom.config.get 'editor-background.youTubeUrl'
      if url? then @ytid = @getYTid(url)
    if @ytid then @animPath = @videoDir+'/'+@ytid+'_images/'


  setSpeed:(speed)->
    @speed = speed

  getYTId: (url) ->
    if url!=''
      ytreg = /// (?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)
      |youtu\.be\/)([^"&?\/ ]{11}) ///i
      ytidregres=ytreg.exec(url)
      if ytidregres?.length>0
        ytid=ytidregres[1]

  imageLoaded:(file,img,event)->
    @loaded++
    if @loaded == @frames.length
      @createCanvas()
      @naturalWidth = img.naturalWidth
      @naturalHeight = img.naturalHeight
      @playing = true
      @animate()



  addFrame:(file)->
    img = new Image()
    img.addEventListener 'load',(event)=>
      @imageLoaded.apply @,[file,img,event]
    img.src = @animPath+file
    @frames.push img

  start:(element,before)->
    @frames = []
    @element = element
    @before = before
    try
      fs.readdir @animPath,(err,files)=>
        if err then console.log err
        else
          reg=///^[0-9]+\.jpg$///
          files.sort (a,b)->
            parseInt(reg.exec(a))-parseInt(reg.exec(b))
          @addFrame file for file in files
    catch e
      console.log e


  drawFrame:->
    if @currentFrame+1>=(@frames.length - @fadeOut)
      @currentFrame = 0
    if @currentFrame<@fadeOut
      lastFrame = @frames.length - 1
      diff = @fadeOut - @currentFrame
      index = lastFrame - diff
      alpha = parseFloat( (diff / @fadeOut).toFixed(2) )
    frame = @frames[@currentFrame]
    @ctx.globalAlpha = 1
    @ctx.drawImage frame,0,0
    if @currentFrame<@fadeOut
      @ctx.globalAlpha = alpha
      @ctx.drawImage @frames[index],0,0
    @currentFrame++


  animate:->
    if @playing
      @drawFrame()
      setTimeout =>
        @animate()
      , @speed


  createCanvas:->
    @canvas = document.createElement 'canvas'
    width = @frames[0].naturalWidth
    height = @frames[0].naturalHeight
    #console.log 'frames',@frames.length
    @canvas.width = width
    @canvas.height = height
    width2 = width // 2
    height2 = height // 2
    body = document.querySelector 'body'
    bdW_ = window.getComputedStyle(body).width
    bdW = /([0-9]+)/gi.exec(bdW_)[1]
    ratio = (bdW / width).toFixed(2)
    @canvas.className = 'editor-background-animation'
    @canvas.style.cssText = "
    position:absolute;
    left:calc(50% - #{width2}px);
    top:calc(50% - #{height2}px);
    width:#{width}px;
    height:#{height}px;
    transform:scale(#{ratio}) translate3d(0,0,0);
    "
    atom.config.observe 'editor-background.blurRadius',(radius)=>
      @canvas.style.webkitFilter="blur(#{radius}px)"

    @ctx = canvas.getContext("webgl")
    if !@ctx
      @ctx = canvas.getContext("experimental-webgl")
    vertexShader = createShaderFromScriptElement(gl, "2d-vertex-shader")
    fragmentShader = createShaderFromScriptElement(gl, "2d-fragment-shader")
    program = createProgram(gl, [vertexShader, fragmentShader])
    gl.useProgram program
    positionLocation = gl.getAttribLocation(program, "a_position")
    buffer = gl.createBuffer()
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer)

    gl.enableVertexAttribArray(positionLocation)
    gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0)


    if @before?
      @element.insertBefore @canvas,@before
    else
      @element.appendChild @canvas

  stop:->
    @canvas.remove()
    @frames = []
    @currentFrame = 0

module.exports = Animation
