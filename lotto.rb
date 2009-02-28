require 'yaml'
require 'rubygems'
require 'httpclient'

def millions(num)
  res= num % 1000000
  res == 0 ? (num / 1000000) : num.to_f / 1000000
end

##  TODO:  add a command line option to force a status update

##  grab the front page from the lotto site
url = "http://californialottery.com/Games/SuperLottoPlus"
client = HTTPClient.new
resp = client.get(url)

##  extract current valuse.  this section is subject to the whims of
##  the calottery site.  Things will change unpredictably.
current={}
current['Jackpot']= resp.content.gsub(/.*id="GameLargeImageBanner1_lblCurJackpot"[^0-9*]*([0-9,]*).*/m, '\1').gsub(/,/, '')
current['CashValue']= resp.content.gsub(/.*id="GameLargeImageBanner1_lblSLPEstCashValue"[^0-9]*([0-9,]*).*/m, '\1').gsub(/,/, '')
current['DrawDate']= resp.content.gsub(/.*id="GameLargeImageBanner1_lblSLCJPTDate"[^0-9]*([0-9\/]*).*/m, '\1').gsub(/,/, '')
##puts "current jackpot= #{current['Jackpot']}\ncash value= #{current['CashValue']}\n"

##  grab the values cached from the last run.  These are the values
##  that were last tweeted.
cached= YAML::load(File.open('./savedItems.yaml'))
##puts "cached jackpot= #{cached['Jackpot']}\ncash value= #{cached['CashValue']}\n"

changed=nil
current.keys.each { |k| changed= current["#{k}"] != cached["#{k}"]; break if changed}

if (changed)
  require 'twitter'

  ##  Cache the new values.
  File.open("./savedItems.yaml", 'w') { |f| f.puts current.to_yaml }

  ##  stitch together a message and blast it out
  str= "The next drawing on #{current['DrawDate']} has a projected jackpot of about $#{millions(current['Jackpot'].to_i)} million.  The cash value is around $#{millions(current['CashValue'].to_i)} million."

  client = Twitter::Client.new(:login => 'casuperlotto', :password => 'coltrane')
  status = client.status(:post, str)

  ##  log message tweeted.
  puts "TWEET: '#{str}'"

else
  ##  log nothing changed
  puts "No change, cached values are unmodified"
end

