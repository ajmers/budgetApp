require 'haml'
require 'sinatra'
require 'sequel'
require 'sinatra/js'

set :haml, :format => :html5

db = Sequel.connect('postgres://localhost/budget')

costCats = db["select distinct item from receipts where item like '1%'"]


get '/' do
    @receipt = db[:receipts].first
    @cats = costCats.map(:item)
    haml :index
end

get '/hello/:cat' do
    @cats = costCats.map(:item)

end

