fs = require 'fs'
{$} = require 'atom-space-pen-views'
popup = require './popup'

class ConfigWindow

  title = null
  content = null
  buttons = null
  settings = {}


  constructor:(@packageName,options)->

    if options?.onChange?
      @onChange = options.onChange
    if options?.onshow?
      @onShow = options.onShow
    if options?.onHide?
      @onHide = options.onHide
    @html = ''
    @popup = new popup()
    @cleanPackageName = @cleanName(@packageName)
    @title = @cleanPackageName+" settings"
    @loadSettings()

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

  upper:(match)->
    match.toUpperCase()


  lower:(match)->
    match.toLowerCase()

  cleanName:(name)->
    dotPos = name.lastIndexOf('.')
    if dotPos>-1
      result = name.substr(dotPos+1,name.length-dotPos-1)
    else
      result = name
    result=result
    .replace '-',' '
    .replace /([a-z]+)([A-Z]+)/g,"$1 $2"
    .replace /^[a-z].(.*)/gi,@lower
    .replace /^([a-z]{1})/gi,@upper
    result

  getConfigValue:(name,obj)->
    fullPath = name
    value = atom.config.get fullPath
    schema = atom.config.getSchema fullPath
    if not value?
      if obj?.default?
        value = obj.default
      else
        if schema?.default?
          value = schema.default
          value = atom.config.makeValueConformToSchema fullPath,value
    value


  # prepare modified schema with value inside for easy parsing to atoms.config
  schemaToInternalConfig:(fullPath)->
    result = {}
    schema = atom.config.getSchema fullPath
    type = schema.type
    if type == 'object'
      props = schema.properties
      for key,val of props
        do(key,val)=>
          result[key] = @schemaToInternalConfig fullPath+'.'+key
    else
      for key,val of schema
        do(key,val)->
          result[key]=val
      # first make value default
      result.value = atom.config.makeValueConformToSchema fullPath,schema.default
      # but if value exists in settings ...
      config = atom.config.get fullPath
      if config?
        result.value = config
    result


  # get value from config with default if not present
  get:(fullPath)->
    internalConfig = @schemaToInternalConfig fullPath
    result = {}
    # we must convert our internal config to atoms.config
    if internalConfig?
      # if type is not present then it is object with children
      keys = Object.keys(internalConfig)
      if not internalConfig.type? and keys != []
        for key in keys
          do (key)=>
            result[key] = @get fullPath+'.'+key
      else
        result = internalConfig.value
    result


  getChildCleanName:(name,obj)->
    cleanName = @cleanName name
    if obj.title?
      cleanName = obj.title
    cleanName

  parseFileChild:(name,obj)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    if not value? then value = ''
    "
    <div class='group'>
      <label for='#{name}'>#{cleanName}</label>
      <input type='text' class='file-text' name='#{name}' id='#{name}'
        value='#{value}'><button class='btn btn-default file-btn'>...</button>
      <input type='file' id='file-#{name}' style='display:none;'>
    </div>
    "

  parseTextChild:(name,obj)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    if not value? then value = ''
    "
    <div class='group'>
      <label for='#{name}'>#{cleanName}</label>
      <textarea
        class='file-text'
        name='#{name}'
        id='#{name}'
        value='#{value}'>#{value}</textarea>
    </div>
    "

  parseStringChild:(name,obj)->
    if obj.toolbox?
      if obj.toolbox == 'file'
        return @parseFileChild name,obj
      if obj.toolbox == 'text'
        return @parseTextChild name,obj
      if obj.toolbox == 'ignore'
        return ""
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
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
      <label for='#{name}'>#{cleanName}</label>
      <select name='#{name}' id='#{name}'>
        #{options}
      </select>
    </div>
    "

  parseColorChild:(name,obj)->
    cleanName = @getChildCleanName name,obj
    value = @getConfigValue name,obj
    value = value.toHexString()
    "
    <div class='group'>
      <label for='#{name}'>#{cleanName}</label>
      <input type='text' class='color-picker' name='#{name}' id='#{name}' value='#{value}'>
    </div>
    "

  parseTabChild:(name,value,level,path)->
    parsers = {
      'string':(name,value)=>@parseStringChild name,value,
      'integer':(name,value)=>@parseIntegerChild name,value,
      'number':(name,value)=>@parseNumberChild name,value,
      'boolean':(name,value)=>@parseBooleanChild name,value,
      'object':(name,value)=>@parseObjectChild name,value,
      'array':(name,value)=>@parseArrayChild name,value,
      'color':(name,value)=>@parseColorChild  name,value
    }
    #console.log 'parsing child tab',name,level,path
    if not value.enum?
      parsers[value.type] path,value,level+1
    else
      @parseEnumChild path,value,level+1

  makeTabs:(name,obj,level,path)->
    cleanName = @getChildCleanName name,obj
    props = obj.properties
    tabs = Object.keys(props)
    #console.log 'tabs',tabs
    level = 0
    html = "<div class='config-tabs'>"
    index = 0
    for tab in tabs
      do (tab)=>
        #console.log 'parsing tab',tab,props[tab]
        if not props[tab].toolbox?
          tabText = @cleanName tab
          html += "<div class='tab' id='tab-index-#{index}'>#{tabText}</div>"
    html += "</div>" # header tabs

    html+="<div class='config-content'>"
    for key,value of props
      do (key,value) =>
        #console.log 'parsing tab content',key
        if !value.toolbox?
          html += "<div class='tab-content' id='content-tab-index-#{index}'>"
          html += @parseObjectChild key,value,1,path+'.'+key
          html += "</div>"
    html += "</div>"
    html

  parseObjectChild:(name,obj,level,path)->
    if !level? then level = 0
    path ?= ''
    #console.log 'parsing object child',name,obj,level
    if level > 10
      console.error 'too much levels... :/'
      throw new Error('something goes terribly wrong... I\'m going out of here')
      return
    html = ''
    if level==0
      html += @makeTabs name,obj,0,name
    else
      props = obj.properties
      for key,value of props
        do (key,value)=>
          html += @parseTabChild key,value,level+1,path+'.'+key
    html

  addButtons:->
    html="
    <button id='apply-btn' class='btn btn-default popup-btn'>Apply</button>
    <button id='close-btn' class='btn btn-default popup-btn'>Close</button>
    "
    @popup.buttons.innerHTML = html
    applyBtn = @popup.element.querySelector '#apply-btn'
    applyBtn.addEventListener 'click',(ev)=>@applyConfig(ev)
    closeBtn = @popup.element.querySelector '#close-btn'
    closeBtn.addEventListener 'click',(ev)=>@close(ev)

  loadSettings:->
    @settings = {}
    @schema = atom.config.schema.properties[@packageName]
    @config = atom.config.get(@packageName)
    @default = atom.config.get(@packageName)
    @path = ''
    @html = '<div id="editor-background-config">'
    @html += @parseObjectChild @packageName,@schema,0
    @html += "</div>"

    @popup.content.innerHTML = @html
    @popup.title.innerHTML = @cleanPackageName
    @configWnd = @popup.element.querySelector '.content'
    @tabs = @configWnd.querySelectorAll '.tab'
    @tabsContent = @configWnd.querySelectorAll '.tab-content'
    for index in [0..(@tabs.length-1)]
      do (index)=>
        @tabs[index].addEventListener 'click',(ev)=>
          @activateTab index

    @activateTab 0
    @bindEvents()
    @addButtons()



  saveSettings:(settings)->
    values = {}
    elements = @popup.content.elements
    for elem in elements
      do(elem)->
        name = elem.name
        if name!= ''
          if elem.type == 'checkbox'
            values[name]=elem.checked
          else
              values[name]=elem.value
    #console.log values
    for key,val of values
      do (key,val)->
        atom.config.set(key,val)


  fileChooser:(ev)->
    elem = ev.target
    $(elem).parent().children('input[type="file"]').click();

  fileChanged:(ev)->
    if ev.target.files[0]?
      file = ev.target.files[0]
      path = file.path.replace(/\\/gi,'/')
      $(ev.target).parent().children('input[type="text"]').val(path)

  bindEvents:->
    $(@configWnd).find('.file-btn').on 'click',(ev)=>@fileChooser(ev)
    file = @configWnd.querySelector 'input[type="file"]'
    file.addEventListener 'change',(ev)=>
      @fileChanged(ev)

  applyConfig:(ev)->
    @saveSettings()
    if @onChange?
      @onChange()


  close:(ev)->
    @popup.hide()


  activateTab:(index)->
    @tabs = $(@popup.element).find('.tab')
    for i in [0..(@tabs.length-1)]
      do (i)=>
        if i==index
          @tabs[i].className='tab active'
        else
          @tabs[i].className = 'tab'

    @tabsContent = $(@popup.element).find('.tab-content')

    for j in [0..(@tabsContent.length-1)]
      do (j)=>
        if j==index
          @tabsContent[j].className = "tab-content active"
        else
          @tabsContent[j].className = "tab-content"
    @popup.center()

  show:->
    @popup.show()

  hide:->
    @popup.hide()

module.exports = ConfigWindow
