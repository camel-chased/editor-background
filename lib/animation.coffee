fs = require 'fs'
path = require 'path'

class Animation

  ytid:''
  homeDir:''
  videoDir:''
  animPath:''
  frames:[]
  currentFrame:0
  fadeOut:50
  canvas:undefined


  constructor: (ytid) ->
    @loaded = 0
    @playing = false
    @speed = atom.config.get 'editor-background.video.animationSpeed'
    atom.config.observe 'editor-background.video.animationSpeed',(speed)=>
      @setSpeed(speed)
    atom.config.observe 'editor-background.video.opacity',(opacity)=>
        vOpacity = (opacity/100).toFixed(2)
        if @canvas?.style?
            @canvas.style.opacity = vOpacity
    @homeDir = atom.packages.resolvePackagePath('editor-background')
    if !@homeDir
      @homeDir = path.resolve(__dirname)
    @videoDir = @homeDir + '/youtube-videos'
    if ytid?
      @ytid = ytid
    else
      url = atom.config.get 'editor-background.video.youTubeUrl'
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
      @player = setTimeout =>
        @animate()
      , @speed


  createCanvas:->
    if !@canvas?
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
      _vOpacity = atom.config.get 'editor-background.video.opacity'
      vOpacity = (_vOpacity / 100).toFixed(2)
      @canvas.style.cssText = "
      position:absolute;
      left:calc(50% - #{width2}px);
      top:calc(50% - #{height2}px);
      width:#{width}px;
      height:#{height}px;
      transform:scale(#{ratio}) translate3d(0,0,0);
      opacity:#{vOpacity};
      "
      atom.config.observe 'editor-background.image.blur',(radius)=>
        @canvas.style.webkitFilter="blur(#{radius}px)"
      @ctx = @canvas.getContext '2d'
      if @before?
        @element.insertBefore @canvas,@before
      else
        @element.appendChild @canvas

  stop:->
    if @player?
        clearTimeout @player
    if @canvas?
        @canvas.remove()
    @frames = []
    @currentFrame = 0
    @playing = false

module.exports = Animation
