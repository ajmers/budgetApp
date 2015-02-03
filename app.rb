require 'haml'
require 'sinatra'
require 'sequel'
require 'sinatra/js'
require 'json'

set :haml, :format => :html5

db = Sequel.connect('postgres://localhost/budget')

items_sql = "select distinct item from receipts order by item asc"

categories_arr = db["select distinct items.expense from items join receipts on receipts.item = items.item where receipts.item like '1%' order by items.expense"].map(:expense)

year_months_sql = "select distinct to_char(date, 'YYYY-MM') as year_month from receipts where to_char(date, 'YYYY-MM')>= ? order by year_month asc"

costs_sql = "select round(sum(amount), 2) as amount,
    to_char(date, 'YYYY-MM') as month
    from receipts join items
    on receipts.item = items.item
    where items.expense = ?
        and date >= ?
        and funding = 'General'
    group by items.expense, month, items.order
    order by items.order desc limit 12"

subcategory_costs_sql = "select round(sum(amount), 2) as amount,
    to_char(date, 'YYYY-MM') as month
    where item = ?
        and date >= ?
        and funding = 'General'
    group by item, month
    order by item desc"


earliest_date = Date.strptime("2010-07", "%Y-%m")

get '/' do

    @year_months = db.fetch(year_months_sql, earliest_date).map(:year_month)
    haml :input
end

get '/receipts/new' do
    @columns = {
        'date'=> {'type' => 'date'},
        'name'=> {'type' => 'text'},
        'amount'=> {'type' => 'number'},
        'description'=> {'type' => 'text'},
        'item'=> {'type' => 'select'},
        'method'=> {'type' => 'text'},
        'funding'=> {'type' => 'text'},
        'expense'=> {'type' => 'text'},
        'envelope'=> {'type' => 'text'},
        'roommate'=> {'type' => 'text'},
        'notes'=> {'type' => 'text'},
        'tag'=> {'type' => 'text'}
        }
    @items = db.fetch(items_sql).map(:item)

    haml :new_receipt
end

post '/receipts/new' do
    puts params
end

post '/' do
    series_array = []
    drilldown_array = []

    @date = Date.strptime(params[:date], "%Y-%m")

    @year_months = db.fetch(year_months_sql, params[:date]).map(:year_month)[0..11]
    @cats = categories_arr

    @cats.each do |cat|
        series = Hash.new
        data = db.fetch(costs_sql, cat, @date)#.map{|x| x[:amount].to_f}
        data_array = @year_months.dup
        series_data = set_series_data(data, data_array)

        series['name'] = cat
        series['data'] = series_data
        series['drilldown'] = cat
        series_array.push(series)

    end

    @series = series_array.to_json
    haml :index
end



def set_series_data(data, data_array)
    data.each do |x|
        index = data_array.index(x[:month])
        if index
            data_array[index] = x[:amount].to_f
        end
        data_array.each do |x|
            if @year_months.include? x
                x = 0
            end
        end
    end
    return data_array
end

