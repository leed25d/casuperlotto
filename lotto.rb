require 'yaml'
require 'rubygems'
require 'httpclient'

def doer(num)
  res= num % 1000000
  res == 0 ? (num / 1000000) : num.to_f / 1000000
end

url = "http://www.calottery.com/default.htm"
client = HTTPClient.new

resp = client.get(url)

current={}
current['Jackpot']= resp.content.gsub(/.*alt='Current SuperLotto Plus Jackpot Amount:\s\$([0-9,]*).*/m, '\1').gsub(/,/, '')
current['CashValue']= resp.content.gsub(/.*id="HomePageGameJackpots1_lblSLPEstCashValue"[^\$]*\$([0-9,]*).*/m, '\1').gsub(/,/, '')
current['DrawDate']= resp.content.gsub(/.*id="HomePageGameJackpots1_lblSLJPTDate"[^0-9]([0-9\/]*).*/m, '\1')
##puts "current jackpot= #{current['Jackpot']}\ncash value= #{current['CashValue']}\n"

cached= YAML::load(File.open('./savedItems.yaml'))
##puts "cached jackpot= #{cached['Jackpot']}\ncash value= #{cached['CashValue']}\n"

changed=0
current.keys.each { |k| changed= current["#{k}"] != cached["#{k}"]; break if changed}

if (changed)
  File.open("./savedItems.yaml", 'w') { |f| f.puts current.to_yaml }

  require 'twitter'
  require 'time'
  require 'linguistics'
  Linguistics::use( :en )

  str= "The California super lotto drawing for #{current['DrawDate']} has a projected jackpot of about #{doer(current['Jackpot'].to_i).en.numwords} million dollars.  The cash value is around #{doer(current['CashValue'].to_i).en.numwords} million dollars."

  client = Twitter::Client.new(:login => 'casuperlotto', :password => 'coltrane')
  status = client.status(:post, str)
  puts "#{status}"
  ##puts "will twitter....#{str}"
else
  puts "No change, cached values are unmodified"
end

