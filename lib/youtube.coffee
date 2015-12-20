fs = require 'fs'
request = require 'request'
itag_formats = require './formats.js'
{Emitter} = require 'event-kit'
mp4 = require './iso_boxer.js'

class YouTube


  INFO_URL = 'https://www.youtube.com/api_video_info?html5=1&hl=en_US&c=WEB&cplayer=UNIPLAYER&cver=html5&el=embedded&video_id='
  VIDEO_EURL = 'https://youtube.googleapis.com/v/'
  HEADER_SIZE = 438

  ytid = ''
  videoInfo = {}
  formats = []
  duration = 0

  constructor:(url)->
    @ytid = @getYTId url
    @emitter = new Emitter
    #console.log 'youtube lib initialized',@ytid

  getYTId: (url) ->
    if url!=''
      ytreg = /// (?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)
      |youtu\.be\/)([^"&?\/ ]{11}) ///i
      ytidregres=ytreg.exec(url)
      if ytidregres?.length>0
        ytid=ytidregres[1]




  parseTime: (time) ->
   #console.log 'parseTime',time
    timeRegexp = /(?:(\d+)h)?(?:(\d+)m(?!s))?(?:(\d+)s)?(?:(\d+)(?:ms)?)?/
    result = timeRegexp.exec(time.toString())
    hours  = result[1] || 0
    mins   = result[2] || 0
    secs   = result[3] || 0
    ms     = result[4] || 0
    res = hours * 3600000 + mins * 60000 + secs * 1000 + parseInt(ms, 10)
   #console.log 'res',res
    res


  on:(event,func)->
    @emitter.on event,func


  getMap: (map)->
    streamMap = map.split(',')
    streams = []
    for map,i in streamMap
      streamData = map.split('&')
      for data in streamData
        [key,value]=data.split('=')
        if !streams[i]? then streams[i]={}
        streams[i][key]=unescape(value)
    streams


  getVideoInfo:(url,next)->
    if url?
      @ytid = @getYTId url
    if @ytid ==  '' then return
    reqUrl = INFO_URL+@ytid
    #console.log 'reqUrl',reqUrl
    request reqUrl,(err,response,body)=>
      if err?
       #console.log 'error',err
        return
      info = body.split('&')

      temp = {}
      for param in info
        [key,value] = param.split('=')
        value = unescape(value)

        if !Array.isArray(temp[key]) and temp[key]?
          old = temp[key]
          temp[key] =  []
          temp[key].push old

        if Array.isArray temp[key]
          temp[key].push unescape(value)

        if not temp[key]?
          temp[key] = value

      if temp.status!='ok'
        #console.log 'error',temp.reason
        msg = temp.reason.toString('UTF-8').replace(/\+/gi,' ')
        atom.notifications.addWarning msg
        return

      @basicStreams = @getMap temp.url_encoded_fmt_stream_map
      @adaptiveStreams = @getMap temp.adaptive_fmts

      #console.log temp

      @formats = {}
      for adaptive in @adaptiveStreams
        itag = adaptive.itag
        if adaptive.type.substr(0,9)=='video/mp4'
          @formats[itag] = adaptive
          if @formats[itag].size?
            size = @formats[itag].size.split('x')
            @formats[itag].width = size[0]
            @formats[itag].height = size[1]

          @formats[itag].urlDecoded = unescape(adaptive.url)
          urlDec = @formats[itag].urlDecoded
          [url,paramStr] = /^https?\:\/\/[^?]+\?(.*)$/gi.exec(urlDec)
          params = paramStr.split('&')
          urlParams={}
          for param in params
            [key,value]=param.split('=')
            urlParams[key]=unescape(value)
          @formats[itag].urlParams = urlParams

      #console.log 'formats finished',@formats
      @emitter.emit 'formats',@formats
      @emitter.emit 'ready'
      if next?
        next(@formats)


  parseRange:(range)->
    if range?
      [start,end] = range.split('-')
      startMs = @parseTime(start)
      endMs = @parseTime(end)
      if not stratS<endS
        #console.error 'Range is invalid'
        return
      [startMs,endMs]


  findChunks:(start,end,next)->
    chunks = []
    @downloadIndexes = []
    start = start / 1000 * @timescale
    end = end / 1000 * @timescale
    #console.log 'start,end',start,end
    for chunk,i in @chunks
     #console.log chunk.startTime,chunk.endTime
      if start < chunk.endTime && chunk.startTime < end
        chunks.push chunk
        @downloadIndexes.push i
    @chunksToDownload = chunks
    #console.log 'chunksToDownload',chunks
    if next? then next(chunks)


  getChunk:(index)->
    chunk = @chunksToDownload[index]
    if chunk?
      range = chunk.startByte+'-'+chunk.endByte
      url = @formats[@itag].urlDecoded+'&range='+range
     #console.log 'getting range',range
      host =  /^https?\:\/\/([^\/]+)\/.*/gi.exec(url)
     #console.log 'host',host[1]
      reqObj = {url:url,headers:{'Host':host[1]},encoding:'binary'}
      request reqObj,(err,res,body)=>
        buff = new Uint8Array(body.length)
        for i in [0..body.length]
          buff[i]=body.charCodeAt(i)
        percent = (index / @chunksToDownload.length) * 100
        @emitter.emit 'data',{current:index,all:@chunksToDownload.length,data:buff,percent:percent}
        @chunks[index].data=body
        @chunks[index].dataArray=buff.buffer
        @downloadedChunks.push @chunks[index]
        if index == @chunksToDownload.length-1
          @fileStream.end body,'binary',(err)=>
            if !err? then @emitter.emit 'done',@downloadedChunks
        else
          @fileStream.write body,'binary',(err)=>
            if !err? then @getChunk(index+1)
    else
      @emitter.emit 'done',@downloadedChunks


  getChunks:->
    @downloadedChunks = []
    @getChunk(0)

  parseTimes:(obj)->
    #console.log 'calculatingChunks',obj
    @start = 0
    @end = @parseTime("10s")
    if obj.time?
      @start = obj.time.start = @parseTime(obj.time.start)
      @end = obj.time.end = @parseTime(obj.time.end)

  int32toBuff8:(number)->
    int32 = new Uint32Array(1)
    int32[0]=number
    buff8temp = new Uint8Array(int32.buffer.slice(0,4))
    buff8 = new Uint8Array(4)
    for i in [0..3]
      buff8[i]=buff8temp[3-i]
    buff8

  makeNewHeader:(next)->
    sidx = @newHeader.fetch('sidx')
    refCount = sidx.reference_count
    #console.log 'downloadIndexes',@downloadIndexes
    # 12 is size of reference chunk
    #console.log 'sidx.size',sidx.size
    newRefsSize = @downloadIndexes.length*12
    delRefsSize = sidx.reference_count*12 - newRefsSize
    #console.log 'newRefsSize,delRefsSize',newRefsSize,delRefsSize

    newSidxSize = sidx.size - delRefsSize
    newHeaderSize = @newHeader._raw.byteLength - delRefsSize
    #console.log 'newSidxSize,newHeaderSize',newSidxSize,newHeaderSize

    sidx._raw.setUint32(0,newSidxSize) # sidx size changed
    sidx._raw.setUint16(30,@downloadIndexes.length) # reference_count


    #console.log 'sidx.size',sidx._raw.getUint32(0)
    #console.log 'sidx.reference_count',sidx._raw.getUint16(30)

    newReferences = new Uint8Array( newRefsSize )

    y = 0
    for index in @downloadIndexes
     #console.log 'copying index',index
      for j in [index*12..index*12+11]
        byte =  sidx._raw.getUint8(j+32) # 32 is references data offset
       #console.log 'j,byte',j,byte
        newReferences[y] = byte
        y++

    headerData = new Uint8Array( newHeaderSize )

   #console.log 'copying all header data'
    # full header clone
    for i in [0..(newHeaderSize-1)]
      headerData[i] = @newHeader._raw.getUint8(i)

    referencesOffset = sidx._offset+32 # 32 = sidx header without references
    #console.log 'copying references at offset',referencesOffset
    for i in [0..(newRefsSize-1)]
      byte = newReferences[ i ]
     #console.log 'newReferences[i],i,referencesOffset+i',byte,i,i+referencesOffset,'"'+String.fromCharCode(byte)+'"'
      headerData[ i+referencesOffset ] = byte

    # tkhd and mvhd durations must be updated too

    tkhd = @newHeader.fetch('tkhd')
    # tkhd
    # full box 12bytes size(4)|tkhd(4)|ver(1)|flags(3)
    # size(4)|tkhd(4)|ver(1)|flags(3)|creation_time(4)|modification_time(4)|track_ID(4)|reserver(4)|duration(4) ...
    mvhd = @newHeader.fetch('mvhd')
    # mvhd
    # full box 12bytes size(4)|mvhd(4)|ver(1)|flags(3)
    # size(4)|mvhd(4)|ver(1)|flags(3)|creation_time(4)|modification_time(4)|timescale(4)|duration(4) ...
    mdhd = @newHeader.fetch('mdhd')
    # mdhd
    # full box 12bytes size(4)|mdhd(4)|ver(1)|flags(3)
    # size(4)|mdhd(4)|ver(1)|flags(3)|creation_time(4)|modification_time(4)|timescale(4)|duration(4) ...
   #console.log 'tkhd,mvhd,mdhd',tkhd,mvhd,mdhd

    newDuration = 0
    for chunk in @chunksToDownload
      newDuration += chunk.duration
   #console.log 'newDuration',newDuration,'real',newDuration/@timescale

    buff8 = @int32toBuff8(newDuration)
    for i in [0..3]
      headerData[ mvhd._offset+24+i ] = buff8[i]
    for i in [0..3]
      headerData[ tkhd._offset+28+i ] = buff8[i]
    for i in [0..3]
      headerData[ mdhd._offset+24+i ] = buff8[i]

     #console.log 'buff8[i]',buff8[i]

   #console.log 'headerData',headerData.buffer.byteLength
    checkNewHeader = mp4.parseBuffer( headerData.buffer )
   #console.log 'checkNewHeader',checkNewHeader
    newHeaderStr = String.fromCharCode.apply(null,headerData)
   #console.log 'newHeaderStr',newHeaderStr.length,newHeaderStr
    @fileStream.write newHeaderStr,'binary',(err)=>
      if err?
        #console.error err
        return
      next()

  getHeader:(next)->
    initRange = @formats[@itag].init.split('-')
    indexRange = @formats[@itag].index.split('-')
    range = '0-'+indexRange[1]
    url = @formats[@itag].urlDecoded+'&range='+range
   #console.log 'init',url
    host =  /^https?\:\/\/([^\/]+)\/.*/gi.exec(url)
    reqObj = {url:url,headers:{'Host':host[1]},encoding:'binary'}
    request reqObj,(err,res,body)=>

      @fileStream = fs.createWriteStream(@filename)
      buff = new Uint8Array(body.length)
      text = ''
      for i in [0..body.length]
        buff[i]=body.charCodeAt(i)

      box = mp4.parseBuffer(buff.buffer)

      @newHeader = mp4.parseBuffer(buff.buffer)

     #console.log 'box',box
      @sidx = box.fetch('sidx')
      @mvhd = box.fetch('mvhd')
      @timescale = @mvhd.timescale
     #console.log 'timescale',@timescale
      @references = @sidx.references

      @chunks = []
      offset = parseInt(indexRange[1])+1 # end of header
      time = 0
      for reference in @references
        startTime = time
        endTime = time + reference.subsegment_duration - 1
        duration = reference.subsegment_duration
        chunk = {
          startByte: offset,
          endByte: offset + reference.referenced_size-1,
          startTime: startTime,
          endTime: endTime,
          size: reference.referenced_size,
          duration: duration
        }
        @chunks.push chunk
        offset  += reference.referenced_size
        time += reference.subsegment_duration
     #console.log @chunks

      @findChunks @start,@end

      @makeNewHeader ()=>
        next()



  # range = 10s-20s or 1h10m0s-1h15m0s
  download:(obj)->

    if obj.filename?
      @filename = obj.filename
    else
      #console.error 'no filename specified'
      return

    if !obj.itag?
      #console.error 'No format specified'
      return

    @itag = obj.itag
    if !@formats[@itag]?
      #console.error 'Wrong format specified'
      return

    @parseTimes(obj)
    @getHeader =>
      @getChunks()





  destroy:->
    @emitter.dispose()

module.exports = YouTube
