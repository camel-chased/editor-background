fs = require 'fs'
{$} = require 'atom-space-pen-views'

class ConfigWindow

  title = null
  content = null
  buttons = null
  settings = {}
  popup = null

  constructor:(@packageName,options)->

    if options?.onChange?
      @onChange = options.onChange
    if options?.onshow?
      @onShow = options.onShow
    if options?.onHide?
      @onHide = options.onHide
    @html = ''
    @cleanPackageName = @cleanName(@packageName)
    @title = @cleanName+" settings"
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
            <input type="number" class="range" data-slider-range="0,100" id="opacity" name="opacity">
          </div>
        </div>

        <div class="tab-content">
          <div class="group">
            <label for="textBackground">Text background color</label>
            <input type="text" class="color-picker" name="textBackground" id="textBackground">
          </div>
          <div class="group">
            <label>Opacity</label>
            <input type="number" class="range" data-slider-range="0,100" id="textBackgroundOpacity" name="textBackgroundOpacity">
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

  type:(object)->
    funcNameRegex = /function (.{1,})\(/
    if object?.constructor?
      res = (funcNameRegex).exec(object.constructor.toString())
      if res?[1]?
        res[1]
      else
        null
    else
      null


  cleanName:(name)->
    name

  getConfigValue:(fullPath)->
    atom.config.get @packageName+'.'+fullPath


  parseStringChild:(name,obj)->
    if obj.title?
      cleanName = obj.title
    else
      cleanName = @cleanName(name)
    fullPath = @path+'.'+name
    value = getConfigValue fullPath
    str =
      "<div class='group'>
        <label for='#{name}'>#{cleanName}</label>
        <input type='text' name='#{name}' id='#{name}' value='#{value}'>
      </div>"
    str

  parseIntegerChild:(obj)->

  parseNumberChild:(obj)->

  parseBooleanChild:(obj)->

  parseObjectChild:(obj)->

  parseArrayChild:(obj)->

  parseEnumChild:(obj)->

  parseColorChild:(obj)->

  parseTabChild:(name,value,level)->

    parsers = {
      'string':@parseStringChild,
      'integer':@parseIntegerChild,
      'number':@parseNumberChild,
      'boolean':@parseBooleanChild,
      'object':@parseObjectChild,
      'array':@parseArrayChild,
      'enum':@parseEnumChild,
      'color':@parseColorChild
    }

    parsers[value.type] name,value

  parseTabChilds:(tab,childs,level)->
    html = ''
    @path = @path + '.'+tab
    for key,value of childs
      do (key,value)=>
        console.log 'parsing:',key,value.type
        html += @parseTabChild key,value,level
        console.log 'html:',html




  loadSettings:->
    @settings = {}
    @schema = atom.config.schema.properties[@packageName].properties
    @config = atom.config.get(@packageName)
    @default = atom.config.getDefault(@packageName)
    @tabs = {}
    @path = ''
    tabs = Object.keys(@schema)
    for tab in tabs
      do (tab)=>
        clean = @cleanName tab
        @tabs[clean]={}

    for tab in tabs
      do (tab)=>
        childs = @schema[tab].properties
        @parseTabChilds tab,childs


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
