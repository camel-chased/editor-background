fs = require 'fs'

class Popup

  element = null
  fadeTime = 250
  visible = false
  onHide = null

  constructor:(appendElement)->
    if not appendElement?
      appendElement = document.querySelector 'body'

    html = '<div class="wrapper">
    <div class="close">X</div>
    <div class="title"></div>
      <div class="content">
      </div>
      <span class="loading loading-spinner-tiny inline-block"
      id="working"
      style="display:none;"></span>
      <div class="buttons"></div>
    </div>'
    @element = document.createElement 'div'
    @element.className = 'eb-modal-window'
    @element.innerHTML = html
    @element.style.transition = "opacity #{@fadeTime}ms"
    close = @element.querySelector '.close'
    close.addEventListener 'click',(ev)=>
      @hide()
    title = @element.querySelector '.title'
    #title.addEventListener 'mousedown',(ev)=>
      #@dragWindow(ev)
    appendElement.appendChild @element
    @

  destroy:->
    @element.remove()

  center:->
    w_ = window.getComputedStyle(@element).width
    h_ = window.getComputedStyle(@element).height
    ww = /([0-9]+)/gi.exec(w_)
    hh = /([0-9]+)/gi.exec(h_)
    console.log 'ww,hh',ww,hh
    w = ww[1]
    h = hh[1]
    w2 = w // 2
    h2 = h // 2
    @element.style.left = "calc(50% - #{w2}px)"
    @element.style.top = "calc(50% - #{h2}px)"

  show:(attrs)->
    titleHTML = attrs.title
    contentHTML = attrs.content
    titleEl = @element.querySelector '.title'
    contentEl = @element.querySelector '.content'
    buttonsEl = @element.querySelector '.buttons'

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
          console.log 'name,action',name,action
          btn = null
          btn = document.createElement 'button'
          btn.className = 'btn btn-default'
          btn.innerText = name
          btn.addEventListener 'click',(ev)=>
            console.log 'popup.action',action
            action(ev,@)
          buttonsEl.appendChild btn

    @element.style.display='block'
    @element.style.opacity = 1
    @visible = true
    @center()
    if attrs?.onShow?
      console.log attrs.onShow
      attrs.onShow(@)

  hide:->
    @element.style.opacity = 0
    @visible = false
    setTimeout =>
      @element.style.display = 'none'
      if @onHide?
        @onHide(@)
    , @fadeTime


  working:(value)->
    icon = @element.querySelector '#working'
    if value
      icon.style.display='block'
    else
      icon.style.display='none'

module.exports = Popup
