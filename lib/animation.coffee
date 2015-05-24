

class Animation

  ytid:''
  homeDir:''
  videoDir:''
  animPath:''
  frames:[]
  currentFrame:0
  fadeOut:2


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

  imageLoaded:(file,event)->
    @loaded++
    if @loaded == @frames.length
      @createCanvas()
      @playing = true
      @animate()



  addFrame:(file)->
    img = new Image()
    img.addEventListener 'load',(event)=>
      @imageLoaded.apply @,[file,event]
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


  drawFrame:(index)->
    if index? then @currentFrame = index
    if @currentFrame+1>=@frames.length
      @currentFrame = 0
    if @currentFrame<=@fadeOut or @currentFrame+@fadeOut == @frames.length
      @ctx.globalAlpha = 0.5
    else
      @ctx.globalAlpha = 1
    frame = @frames[@currentFrame++]
    @ctx.drawImage frame,0,0

  animate:->
    if @playing
      @drawFrame()
      setTimeout =>
        @animate()
      , @speed


  createCanvas:->
    @canvas = document.createElement 'canvas'
    @canvas.width = @frames[0].naturalWidth
    @canvas.height = @frames[0].naturalHeight
    @canvas.className = 'editor-background-animation'
    @canvas.style.cssText = "
    position:absolute;
    left:0;
    top:0;
    width:100%;
    height:100%;
    "
    @ctx = @canvas.getContext '2d'
    if @before?
      @element.insertBefore @canvas,@before
    else
      @element.appendChild @canvas

  stop:->
    @canvas.remove()
    @frames = []
    @currentFrame = 0

module.exports = Animation
