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

  getConfigValue:(name,obj)->
    fullPath = @packageName+@path+'.'+name
    value = atom.config.get fullPath
    if not value?
      if obj?.default?
        value = obj.default
      else
        value = atom.config.getDefault fullPath
    value

  getChildCleanName:(name,obj)->
    cleanName = @cleanName name
    if obj.title?
      cleanName = obj.title
    cleanName

  parseStringChild:(name,obj)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    console.log 'value',value
    if not value?
      value = ''
    "<div class='group'>
      <label for='#{name}'>#{cleanName}</label>
      <input type='text' name='#{name}' id='#{name}' value='#{value}'>
    </div>"

  parseSliderChild:(name,obj,step)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    min = obj.minimum
    max = obj.maximum
    "
    <div class='group'>
      <label for='#{name}'>#{cleanName}</label>
      <input type='number' class='range'
        data-slider-range='#{min},#{max}'
        data-slider-step='#{step}'
        name='#{name}' id='#{name}' value='#{value}'>
    </div>
    "

  parseIntegerChild:(name,obj)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    if obj.minimum? and obj.maximum?
      step = 1
      if obj.step? then step = obj.step
      @parseSliderChild name,obj,step
    else
      "
      <div class='group'>
        <label for='#{name}'>#{cleanName}</label>
        <input type='number' name='#{name}' id='#{name}' value='#{value}'>
      </div>
      "

  parseNumberChild:(name,obj)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    if obj.minimum? and obj.maximum?
      step = 1
      if obj.step? then step = obj.step
      @parseIntegerSlider name,obj,step
    else
      "
      <div class='group'>
        <label for='#{name}'>#{cleanName}</label>
        <input type='text' name='#{name}' id='#{name}' value='#{value}'>
      </div>
      "

  parseBooleanChild:(name,obj)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    checked = ''
    if value then checked = " checked='checked' "
    "
    <div class='group'>
      <label><input type='checkbox' name='#{name}' id='#{name}' #{checked}>#{cleanName}</label>
    </div>
    "
  parseArrayChild:(name,obj)->
    ''

  parseEnumOptions:(options,selected)->
    result = ''
    for option in options
      do (option)->
        sel = ''
        if selected == option then sel ='selected="selected"'
        result+="
        <option value='#{option}' #{sel}>#{option}</option>
        "
    result

  parseEnumChild:(name,obj)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    options = @parseEnumOptions  obj.enum,value
    "
    <div class='group'>
      <select name='#{name}' id='#{name}'>
        #{options}
      </select>
    </div>
    "

  parseColorChild:(name,obj)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    #value = value.toHexString()
    "
    <div class='group'>
      <label for='#{name}'>#{cleanName}</label>
      <input type='text' class='color-picker' name='#{name}' id='#{name}' value='#{value}'>
    </div>
    "

  parseTabChild:(name,value,level)->
    parsers = {
      'string':(name,value)=>@parseStringChild name,value,
      'integer':(name,value)=>@parseIntegerChild name,value,
      'number':(name,value)=>@parseNumberChild name,value,
      'boolean':(name,value)=>@parseBooleanChild name,value,
      'object':(name,value)=>@parseObjectChild name,value,
      'array':(name,value)=>@parseArrayChild name,value,
      'color':(name,value)=>@parseColorChild  name,value
    }
    console.log 'parsing child tab',name
    if not value.enum?
      parsers[value.type] name,value
    else
      @parseEnumChild name,value

  makeTabs:(name,obj,level)->
    cleanName = @getChildCleanName name,obj
    props = obj.properties
    tabs = Object.keys(props)
    console.log 'tabs',tabs
    html = "<div class='config-tabs'>"
    index = 0
    for tab in tabs
      do (tab)->
        console.log 'parsing tab',tab
        html += "<div class='tab' id='tab-index-#{index}'>#{tab}</div>"
    html += "</div>" # header tabs

    html+="<div class='config-content'>"
    for key,value of props
      do (key,value) =>
        console.log 'parsing tab content',key
        html += "<div class='tab-content' id='content-tab-index-#{index}'>"
        html += @parseTabChild key,value,level+1
        html += "</div>"
    html += "</div>"
    html

  parseObjectChild:(name,obj,level)->
    console.log 'name,obj',name,obj
    if level > 10
      console.error 'too much levels... :/'
      throw new Error('something goes terribly wrong... I\'m going out of here')
      return
    html = ''
    if level==0
      html += @makeTabs name,obj,0
    else
      props = obj.properties
      for key,value of props
        do (key,value)=>
          html += @parseTabChild key,value,level++

  loadSettings:->
    @settings = {}
    @schema = atom.config.schema.properties[@packageName]
    @config = atom.config.get(@packageName)
    @default = atom.config.getDefault(@packageName)
    @path = ''
    @html = '<div id="editor-background-config">'
    @html += @parseObjectChild @packageName,@schema,0
    @html += "</div>"

  getSettings:->
    return
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
    return
    imageURLFileBtn = @configWnd.querySelector '#imageURLFileBtn'
    imageURLFileBtn.addEventListener 'click',(ev)=>@imageURLFileChooser(ev)
    imageURLFile = @configWnd.querySelector '#imageURLFile'
    imageURLFile.addEventListener 'change',(ev)=>@imageURLFileChanged(ev,imageURLFile)


  onShow:(popup)->
    @popup = popup
    @loadSettings()
    popup.content.innerHTML = @html
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
    @tabs = $(@configWnd).find('.tab')
    for i in [0..(@tabs.length-1)]
      do (i)=>
        if i==index
          @tabs[i].className='tab active'
        else
          @tabs[i].className = 'tab'

    @tabsContent = $(@configWnd).find('.tab-content')

    for j in [0..(@tabsContent.length-1)]
      do (j)=>
        if j==index
          @tabsContent[j].className = "tab-content active"
        else
          @tabsContent[j].className = "tab-content"
    @popup.center()

module.exports = ConfigWindow
