fs = require 'fs'
#Slider = require './slider'
{$} = require 'atom'

class ConfigWindow

  title = null
  content = null
  buttons = null
  settings = {}
  popup = null

  constructor:(onApply)->
    @onApply = onApply
    @title = "Editor Background - config - work in progress ;)"
    @content = '
    <div id="editor-background-config">
      <div class="config-tabs">

        <div class="tab config-tab">Image</div>
        <div class="tab config-tab">Text</div>
        <div class="tab config-tab">Video</div>
        <div class="tab config-tab">3D Box</div>
        <div class="tab config-tab">About</div>

      </div>

      <div class="config-content">

        <div class="tab-content">
          <div class="group">
            <label for="imageURL">Image URL</label>
            <input type="text" id="imageURL" name="imageURL" style="width:500px;">
            <input type="file" id="imageURLFile" accept="image/*" style="display:none;">
            <button class="btn btn-default group-addon" id="imageURLFileBtn">...</button>
          </div>
          <div class="group">
            <label>Opacity</label>
            <input type="text" class="range" data-slider-range="0,100" data-slider-step="1" id="opacity" name="opacity">
          </div>
        </div>

        <div class="tab-content">
          <div class="group">
            <label for="textBackground">Text background color</label>
            <input type="text" class="color-picker" name="textBackground" id="textBackground">
          </div>
          <div class="group">
            <label>Opacity</label>
            <input type="text" class="range" data-slider-range="0,100" data-slider-step="1" id="textBackgroundOpacity" name="textBackgroundOpacity">
          </div>
        </div>

        <div class="tab-content">
          second
        </div>

        <div class="tab-content">
          third
        </div>

        <div class="tab-content">
          last
        </div>

      </div>

    </div>
    '
    @buttons = {
      "Apply":(ev,popup)=> @applyConfig(ev,popup),
      "Close":(ev,popup)=> @close(ev,popup)
    }

  loadSettings:->
    @settings = {}
    conf = atom.config.get('editor-background')
    confDefault = atom.config.getDefault('editor-background')
    keys = Object.keys(conf)
    for key in keys
      @settings[key]=conf[key]
      if !@settings[key] and confDefault[key]?
        @settings[key] = confDefault[key]
    console.log 'settings',@settings
    for name,elem of @popup.controls
      do (name,elem)=>
        if elem.type!='file'
          elem.value = @settings[elem.name]


  getSettings:->
    values = {}
    console.log 'popup controls',@popup.controls
    for name,elem of @popup.controls
      do (name,elem)->
        console.log 'elem',name,elem
        if name?
          if name!=''
            values[name]=elem.value
    values

  saveSettings:(settings)->
    keys = Object.keys(settings)
    for key in keys
      atom.config.set('editor-background.'+key,settings[key])

  imageURLFileChooser:->
    fileSelect = @configWnd.querySelector '#imageURLFile'
    console.log 'fileSelect',fileSelect
    fileSelect.click()


  imageURLFileChanged:(ev,file)->
    path = file.files[0].path
    @popup.controls.imageURL.value = path

  bindEvents:->
    imageURLFileBtn = @configWnd.querySelector '#imageURLFileBtn'
    imageURLFileBtn.addEventListener 'click',(ev)=>@imageURLFileChooser(ev)
    imageURLFile = @configWnd.querySelector '#imageURLFile'
    imageURLFile.addEventListener 'change',(ev)=>@imageURLFileChanged(ev,imageURLFile)


  onShow:(popup)->
    @popup = popup
    @loadSettings()
    @configWnd = popup.element.querySelector '#editor-background-config'
    @tabs = @configWnd.querySelectorAll '.tab'
    @tabsContent = @configWnd.querySelectorAll '.tab-content'
    @bindEvents()

    for index in [0..(@tabs.length-1)]
      do (index)=>
        @tabs[index].addEventListener 'click',(ev)=>
          @activateTab index

    @activateTab 0


  applyConfig:(ev,popup)->
    settings = @getSettings()
    console.log 'settings',settings
    @saveSettings settings
    if @onApply?
      @onApply()


  close:(ev,popup)->
    popup.hide()


  activateTab:(index)->
    for i in [0..(@tabs.length-1)]
      do (i)=>
        if i==index
          @tabs[i].className='tab active'
        else
          @tabs[i].className = 'tab'

    for j in [0..(@tabsContent.length-1)]
      do (j)=>
        if j==index
          @tabsContent[j].className = "tab-content active"
        else
          @tabsContent[j].className = "tab-content"
    @popup.center()

module.exports = ConfigWindow
