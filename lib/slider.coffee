
class Slider

  originInput = null
  inputStyle = null
  input = null
  element = null
  area = null
  button = null
  labelStr = ''
  label = null
  input = null
  parent = null
  min = 0
  max = 100

  mouseState = false
  mousePos = null
  mouseOffset = null
  buttonPos = null

  constructor:(args)->
    if !args?.input? then return

    @mouseState = false
    @mousePos = null
    @mouseOffset = null


    @originInput = args.input
    @inputStyle = window.getComputedStyle @originInput
    @originInput.style.display='none'

    @input = document.createElement 'input'
    @input.type = "text"
    @input.style.margin = @inputStyle.margin
    @input.style.width = '40px'
    @input.style.textAlign = 'center'
    @input.value = @originInput.value

    @element = document.createElement 'div'
    @element.className = 'slider-element'
    @element.style.height = @inputStyle.height
    @element.style.overflow = 'hidden'

    @area = document.createElement 'div'
    @area.className = 'slider-area'
    @area.style.float = 'right'
    @area.style.height = '10px'
    @area.style.border = '1px solid '+@inputStyle.borderColor
    @area.style.borderRadius = '10px'
    @button = document.createElement 'div'
    @button.className = 'slider-button btn btn-default'
    @buttonPos = {x:0,y:0}
    @label = document.createElement 'label'

    @left = document.createElement 'div'
    @left.style.float='left'
    @left.appendChild @label
    @left.appendChild @input

    if args.min? then @min = args.min
    if args.max? then @max = args.max
    if args.label? then @labelStr = args.label

    @label.innerText = @labelStr

    @area.style.position = 'relative'
    @area.style.height = '10px'
    @area.style.minWidth = '110px'
    @area.style.width = @inputStyle.width
    @area.style.top='10px'
    @area.style.verticalAlign = 'middle'
    @area.style.boxShadow = 'inset 2px 2px 2px rgba(0,0,0,0.2)'


    @button.style.width = '10px'
    @buttonWidth = 10
    @button.style.height = '12px'
    @button.style.padding = "0"
    if @originInput.value?
      if @originInput.value!=''
        @value = /[0-9]+/gi.exec(@originInput.value)[0]

    @button.style.left = @positionFromValue @value
    @button.style.top = '-2px'
    @button.style.borderRadius = '3px'
    @button.style.position = 'absolute'
    @button.style.transform = "scale(1,1.4)"
    @button.addEventListener 'mousedown',(ev)=>@mouseDown.apply @,[ev]
    window.addEventListener 'mouseup',(ev)=>@mouseUp.apply @,[ev]
    window.addEventListener 'mousemove',(ev)=>@mouseMove.apply @,[ev]

    @area.appendChild @button
    @element.appendChild @left
    @element.appendChild @area
    @parent = @originInput.parentElement
    @prev = @originInput.previousElementSibling
    @next = @originInput.nextElementSibling
    @

    if @prev?
      @parent.insertBefore @element,@prev.nextElementSibling
    else
      if @next?
        @parent.insertBefore @element,@next
      else
        @parent.appendChild @element
    @


  positionFromValue:(value)->
    w = @getAreaWidth()
    left = Math.round((value / 100) * w)
    left + 'px'


  getAreaWidth:->
    comptd = window.getComputedStyle(@area)
    w1 = /[0-9]+/gi.exec(comptd.width)
    w2 = /[0-9]+/gi.exec(comptd.minWidth)
    if w1?[0]?
      @areaWidth = w1[0]
    else
      if w2?[0]?
        @areaWidth = w2[0]
      else
        @areaWidth = 110
    @areaWidth


  mouseDown:(ev)->
    @mouseState = true

  mouseUp:(ev)->
    @mouseState = false
    @mousePos = null


  mouseMove:(ev)->
    if @mouseState
      ev.preventDefault()
      pos = {x:ev.x,y:ev.y}
      if @mousePos?
        diff = { x: pos.x - @mousePos.x , y: pos.y-@mousePos.y }
        @buttonPos.x += diff.x

        @areaWidth = @getAreaWidth()

        if @buttonPos.x < 0 then @buttonPos.x = 0
        if @buttonPos.x + @buttonWidth > @areaWidth
          @buttonPos.x = @areaWidth - @buttonWidth
        @button.style.left = @buttonPos.x+'px'
        range = @areaWidth - @buttonWidth
        @value = Math.round((@buttonPos.x / range) * 100)
        @input.value = @value
        @originInput.value = @value
      @mousePos = pos



module.exports = Slider
