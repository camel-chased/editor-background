

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
    if @loaded == @frames
      @animation[0].style.background = @backgroundCSS
      @animation[1].style.background = @backgroundCSS
      for i in @images.length
        @images.splice i,1
      @playing = true
      @animate()

  addFrame:(file)->
    img = new Image()
    img.addEventListener 'load',(ev)=>@imageLoaded.apply @,[file,ev]
    img.src = @animPath+file
    @images.push img
    @backgroundCSS+='url("'+@animPath+file+'") no-repeat '
    @backgroundCSS+='0px '+@offsetY+'px/100% '+@height+'px,'
    @actualFrameLoading++
    @offsetY = @height * @actualFrameLoading

  filesLoaded:->
    @animation[0].style.height = (@frames * @height)+'px'
    @animation[1].style.height = (@frames * @height)+'px'
    @backgroundCSS = @backgroundCSS.replace(/\,$/gi,'')
    


  start:(element,before)->
    @actualFrameLoading = 0
    @images = []
    @offsetY = 0
    @loaded = 0
    @element = element
    @before = before
    @animationWrapper = document.createElement 'div'
    @animation = []
    @animation.push document.createElement 'div'
    @animation.push document.createElement 'div'
    @animationWrapper.appendChild @animation[0]
    @animationWrapper.appendChild @animation[1]
    @animationWrapper.style.cssText='
    position:absolute;
    left:0;
    top:0;
    width:100%;
    height:100%;
    overflow:hidden;
    '
    body = document.querySelector('body')
    h = window.getComputedStyle(body).height
    hreg = /([0-9]+)/gi.exec(h)
    @height = hreg[1]
    css='
    width:100%;
    position:absolute;
    left:0;
    top:0;
    height:'+@height+'px'
    @animation[0].style.cssText=css
    @animation[1].style.cssText=css
    if @before?
      @element.insertBefore @animationWrapper,@before
    else
      @element.appendChild @animationWrapper
    @backgroundCSS = ''
    try
      fs.readdir @animPath,(err,files)=>
        if err then console.log err
        else
          reg=///^[0-9]+\.jpg$///
          files.sort (a,b)->
            parseInt(reg.exec(a))-parseInt(reg.exec(b))
          @frames = files.length
          @addFrame file for file in files
          @filesLoaded()
    catch e
      console.log e


  drawFrame:(index)->
    if index? then @currentFrame = index
    if @currentFrame+1>=@frames
      @currentFrame = 0
    top = -(@currentFrame*@height)
    @animation.style.top=top+'px'
    @currentFrame++

  animate:->
    if @playing
      @drawFrame()
      setTimeout =>
        @animate()
      , @speed

  stop:->
    @canvas.remove()
    @frames = []
    @currentFrame = 0

module.exports = Animation
