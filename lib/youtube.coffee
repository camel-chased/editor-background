fs = require 'fs'
request = require 'request'
itag_formats = require './formats.js'
{Emitter} = require 'event-kit'

class YouTube

  
  INFO_URL = 'https://www.youtube.com/get_video_info?html5=1&c=WEB&cplayer=UNIPLAYER&cver=html5&el=embedded&video_id='
  VIDEO_EURL = 'https://youtube.googleapis.com/v/'
  HEADER_SIZE = 438
  
  ytid = ''
  videoInfo = {}
  formats = []
  duration = 0

  constructor:(url)->
    @ytid = @getYTId url
    @emitter = new Emitter
    console.log 'youtube lib initialized',@ytid

  getYTId: (url) ->
    if url!=''
      ytreg = /// (?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)
      |youtu\.be\/)([^"&?\/ ]{11}) ///i
      ytidregres=ytreg.exec(url)
      if ytidregres?.length>0
        ytid=ytidregres[1]



  
  parseTime: (time) ->
    console.log 'parseTime',time
    timeRegexp = /(?:(\d+)h)?(?:(\d+)m(?!s))?(?:(\d+)s)?(?:(\d+)(?:ms)?)?/
    result = timeRegexp.exec(time.toString())
    hours  = result[1] || 0
    mins   = result[2] || 0
    secs   = result[3] || 0
    ms     = result[4] || 0
    res = hours * 3600000 + mins * 60000 + secs * 1000 + parseInt(ms, 10)
    console.log 'res',res
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
    console.log 'reqUrl',reqUrl
    request reqUrl,(err,response,body)=>
      if err?
        console.log 'error',err
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
        console.log 'error',temp.reason
        return

      @basicStreams = @getMap temp.url_encoded_fmt_stream_map
      @adaptiveStreams = @getMap temp.adaptive_fmts

      @formats = {}
      for adaptive in @adaptiveStreams
        itag = adaptive.itag
        @formats[itag] = adaptive
        @formats[itag].urlDecoded = unescape(adaptive.url)
        urlDec = @formats[itag].urlDecoded
        [url,paramStr] = /^https?\:\/\/[^?]+\?(.*)$/gi.exec(urlDec)
        params = paramStr.split('&')
        urlParams={}
        for param in params
          [key,value]=param.split('=')
          urlParams[key]=unescape(value)
        @formats[itag].urlParams = urlParams

      console.log 'formats finished',@formats
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
        console.error 'Range is invalid'
        return
      [startMs,endMs]


  timeToBytes:(ms)->
    format = @formats[@itag]
    oneMs = (format.clen-format.index) / @duration
    result = Math.round(oneMs * ms) // 1024 * 1024
    console.log 'ms,oneMs,result',ms,oneMs,result
    result

  getBytesRange:(range,next)->
    url = @formats[@itag].url+'&range='+range
    console.log 'getting range',range
    host =  /^https?\:\/\/([^\/]+)\/.*/gi.exec(url)
    console.log 'host',host[1]
    reqObj = {url:url,headers:{'Host':host[1]},encoding:'binary'}
    #request(reqObj).pipe(@fileStream)
    
    request reqObj,(err,res,body)=>
      console.log 'is buffer?',Buffer.isBuffer(body)
      if res.headers['content-type']=='text/plain'
        @formats[@itag].url = body
        @getBytesRange range,next
        return
      if not Buffer.isBuffer(body)
        buffSize = parseInt(res.headers['content-length'])
        console.log 'buffSize',buffSize
        buff = new Buffer(buffSize,'binary')
        buff.write body,'binary'
        body = buff
      
      result = {bytes:body,size:parseInt(res.headers['content-length'])}
      console.log 'received bytes',result.size,res.headers,result.len
      @emitter.emit 'data',result
      @saveBytes result,next
    

  saveBytes:(result,next)->
    @savedBytes+=result.size
    @currentChunk++
    console.log 'chunk:',@currentChunk,'allBytes:',@savedBytes
    if @currentChunk == Math.ceil( @chunks ) #finished -last chunk
      @fileStream.end result.bytes,'binary',(err)=>
        if err?
          console.error 'Cannot save the file'
          return
        @emitter.emit 'done'
        if next? then next()
    else #not finished yet
      @fileStream.write result.bytes,'binary',(err)=>
        if err?
          console.error 'Cannot save the file'
          return
      start = @savedBytes
      if @currentChunk >= Math.floor( @chunks )
        leftBytes = @endByte - (65535 * Math.floor( @chunks ))
        end = start + leftBytes
      else
        end = start + 65535
      rangeStr = start.toString()+'-'+end.toString()
      @getBytesRange rangeStr,next


  getIndexedFrames:(next)->
    url = @formats[@itag].urlDecoded+'&range='+@formats[@itag].index
    host =  /^https?\:\/\/([^\/]+)\/.*/gi.exec(url)
    reqObj = {url:url,headers:{'Host':host[1]},encoding:'binary'}
    request reqObj,(err,res,body)=>
      console.log res
      if not Buffer.isBuffer(body)
        buff = new Buffer(res.headers['content-length'],'binary')
        buff.write body,'binary'
      else
        buff = body
      frames = []
      len = res.headers['content-length'] / 2
      console.log 'len',len
      for i in [0..len]
        console.log i
        frames.push buff.readUInt8(i)
      console.log 'keyFrames',frames
      @keyFrames = frames
      next(frames)

  getHeader:(next)->
    @getIndexedFrames (indexedFrames)=>
      url = @formats[@itag].urlDecoded+'&range='+@formats[@itag].init
      console.log 'getting Header',url
      host =  /^https?\:\/\/([^\/]+)\/.*/gi.exec(url)
      reqObj = {url:url,headers:{'Host':host[1]},encoding:'binary'}
      request reqObj,(err,res,body)=>
        console.log 'request for header finished',res.headers,body
        if not Buffer.isBuffer(body)
          buff = new Buffer(res.headers['content-length'],'binary')
          buff.write body,'binary'
        else
          buff = body
        @header = buff
        next(buff)


  # range = 10s-20s or 1h10m0s-1h15m0s
  download:(obj)->
    console.log 'download',obj

    @start = 0
    @end = @duration
    @savedBytes = 0
    @currentChunk = 0

    if obj.start?
      @start = @parseTime(obj.start)
    if obj.end?
      @end = @parseTime(obj.end)
      
    if obj.filename?
      @filename = obj.filename
    else
      console.error 'no filename specified'
      return

    if !obj.itag?
      console.error 'No format specified'
      return

    @itag = obj.itag
    if !@formats[@itag]?
      console.error 'Wrong format specified'
      return

    @startByte = @timeToBytes(@start)
    @endByte = @timeToBytes(@end)
    byteRange = @startByte.toString()+'-'+@endByte.toString()
    console.log byteRange
    @durationBytes = @endByte - @startByte
    @chunks = @durationBytes / 65535
    console.log 'chunks',@chunks
    firstRange = @startByte.toString()+'-'+(parseInt(@startByte)+65535).toString()
    console.log 'firstRange',firstRange
    @fileStream = fs.createWriteStream(@filename)
    
    if @startByte!=0
      @getHeader (buffer)=>
        @fileStream.write buffer,'binary',(err)=>
          if !err?
            @getBytesRange firstRange
          else
            console.error err
    else
      @getBytesRange firstRange



  destroy:->
    @emitter.dispose()

module.exports = YouTube
