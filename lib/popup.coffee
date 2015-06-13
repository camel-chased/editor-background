fs = require 'fs'
{$} = require 'atom-space-pen-views'
SimpleSlider = require './simpleSlider'
colorpicker = require './colorpicker.js'

class Popup

  element = null
  content = null
  fadeTime =250
  visible = false
  onHide = null
  controls = {}
  title = null
  buttons = null

  constructor:(appendElement)->
    if not appendElement?
      appendElement = document.querySelector 'body'

    html = '<div class="wrapper">
    <div class="close">X</div>
    <div class="title"></div>
      <form name="contentForm" class="content">
      </form>
      <span class="loading loading-spinner-tiny inline-block"
      id="working"
      style="display:none;"></span>
      <div class="buttons"></div>
    </div>'
    @element = document.createElement 'div'
    @element.className = 'eb-modal-window'
    @element.innerHTML = html
    @content = @element.querySelector '.content'
    @form = @content
    fadeTime = @fadeTime
    @element.style.transition = "opacity #{fadeTime}ms"
    @element.style.webkitTransition = "opacity #{fadeTime}ms"
    close = @element.querySelector '.close'
    close.addEventListener 'click',(ev)=>
      @hide()
    @title = @element.querySelector('.title')
    @buttons = @element.querySelector '.buttons'
    #title.addEventListener 'mousedown',(ev)=>
      #@dragWindow(ev)
    appendElement.appendChild @element
    @element.addEventListener 'keydown',(ev)->
      ev.stopPropagation()
    @

  destroy:->
    @element.remove()

  center:->
    w_ = window.getComputedStyle(@element).width
    h_ = window.getComputedStyle(@element).height
    ww = /([0-9]+)/gi.exec(w_)
    hh = /([0-9]+)/gi.exec(h_)
    if ww? and hh?
      w = ww[1]
      h = hh[1]
      w2 = w // 2
      h2 = h // 2
      @element.style.left = "calc(50% - #{w2}px)"
      @element.style.top = "calc(50% - #{h2}px)"

  getControls:->
    @controls = {}
    @controls.forms = document.forms
    for form in document.forms
      do (form)=>
        for el in form.elements
          do (el)=>
            @controls[el.name]=el

  makeSliders:->
    ranges = @element.querySelectorAll '.range'
    for range in ranges
      do (range)->
        $(range).bind 'change',(ev)->
          val = range.value
          $(range).simpleSlider('setValue',val)

        input = document.createElement 'input'
        input.type = 'text'
        input.style.minWidth='40px'
        range.parentElement.insertBefore input,range
        input.addEventListener 'change',->
          range.value = input.value
        val = range.value || 0
        input.value = val
        dataRange = range.dataset.sliderRange.split(',')
        $(range).simpleSlider({range:dataRange,value:val})
        $(range).bind 'sliderchanged',(ev,data)->
          input.value = data.value

  makeColors:->
    colorPickers = @element.querySelectorAll '.color-picker'
    for picker in colorPickers
      do (picker) ->
        $(picker).wrap('<div class="picker-wrapper"></div>')
        wrapper = $(picker).parent()
        #console.log 'wrapper',wrapper
        cpicker = new colorpicker(picker,{container:wrapper,format:'hex'})
        $(cpicker).focus ->
          $(cpicker).colorpicker('show')

  setVisible:->
    otherModals = document.querySelectorAll '.eb-modal-window'
    zIndex = 1
    for modal in otherModals
      cmpSt = window.getComputedStyle modal
      if cmpSt.zIndex > zIndex then zIndex=cmpSt.zIndex
    @element.style.display='block'
    @element.style.opacity = 1
    @element.style.zIndex = zIndex+1
    @visible = true
    @center()
    @getControls()
    if !@inputParsed
      @makeSliders()
      @makeColors()
      @inputParsed = true

  show:(attrs)->
    if not attrs?
      return @setVisible()

    @inputParsed = false
    titleHTML = attrs.title
    contentHTML = attrs.content
    titleEl = @element.querySelector '.title'
    contentEl = @element.querySelector '.content'
    @content = contentEl
    buttonsEl = @element.querySelector '.buttons'
    @buttons = buttonsEl
    buttonsEl.innerHTML=""
    titleEl.innerHTML = titleHTML
    contentEl.innerHTML = contentHTML

    if attrs.onHide?
      @onHide = attrs.onHide
    else
      @onHide = null

    if attrs?.buttons?
      for name,action of attrs.buttons
        do (name,action)=>
          btn = null
          btn = document.createElement 'button'
          btn.className = 'btn btn-default'
          btn.innerText = name
          btn.addEventListener 'click',(ev)=>
            action(ev,@)
          buttonsEl.appendChild btn

    @setVisible()
    if attrs?.onShow?
      attrs.onShow(@)

  hide:(next)->
    @element.style.opacity = 0
    @visible = false
    setTimeout =>
      @element.style.display = 'none'
      if @onHide?
        @onHide(@)
      if next? then next()
    , @fadeTime

  close:->
    @hide =>
      @content.innerHTML = ''

  destroy:->
    @hide =>
      @element.remove()
      delete @

  working:(value)->
    icon = @element.querySelector '#working'
    if value
      icon.style.display='block'
    else
      icon.style.display='none'

module.exports = Popup
