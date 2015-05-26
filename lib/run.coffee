youtube = require './youtube'


url = "https://www.youtube.com/watch?v=Z76TFE2HGfg"
yt = new youtube(url)


ytid = yt.getYTId url
savePath = '../youtube-videos/'+ytid+'.mp4'



yt.on 'formats',(formats)=>
  
yt.on 'data',(data)=>
	console.log 'data',data
yt.on 'done',=>
  console.log 'download complete'
yt.on 'ready',=>
	yt.download {filename:savePath,itag:134,start:'10s'} 

yt.getVideoInfo()