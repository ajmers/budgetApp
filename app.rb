require 'haml'
require 'sinatra'
require 'sequel'
require 'sinatra/js'
require 'json'
require 'sinatra/contrib'

set :haml, :format => :html5

db = Sequel.connect('postgres://localhost/budget')

class Item < Sequel::Model; end

class Receipt < Sequel::Model; end

defaults = {:funding => 'General', :expense => 'Personal' }

items_set = Receipt.order(Sequel.asc(:item)).distinct(:item)
#items_sql = "select distinct item from receipts order by item asc"

categories_set = Item.order(Sequel.asc(:expense)).grep(:item, '1%').distinct(:expense).map(:expense)
#categories_arr = db["select distinct items.expense from items join receipts on receipts.item = items.item where receipts.item like '1%' order by items.expense"].map(:expense)

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

get '/receipts/new' do
    @columns = {
        :date=> {:type => 'date'},
        :name=> {:type => 'text'},
        :amount=> {:type => 'number'},
        :description=> {:type => 'text'},
        :item=> {:type => 'select'},
        :method=> {:type => 'text'},
        :funding=> {:type => 'text'},
        :expense=> {:type => 'text'},
        :envelope=> {:type => 'text'},
        :roommate=> {:type => 'text'},
        :notes=> {:type => 'text'},
        :tag=> {:type => 'text'}
        }
    @items = items_set.map(:item)

    haml :new_receipt
end

post '/receipts/new' do
    insert_params = {}

    Receipt.columns.each do |column|
        puts column
        if params[column]
            insert_params[column] = params[column]
        end
    end

    already_exists = check_for_duplicates(insert_params)
    if not already_exists
        defaults.each do |key, value|
            if not params[key]
                params[key] = defaults[key]
            end
        end
        new = Receipt.create(insert_params)
        puts new
        redirect '/receipts/new'
    else
        puts 'already exists in db'
        redirect '/receipts/new'
    end
end

route :get, :post, '/' do
    series_array = []
    drilldown_array = []
    puts params

    if params[:date]
        @date = Date.strptime(params[:date], "%Y-%m")
    else
        @date = get_one_year_ago()
        puts @date
    end

    @all_year_months = db.fetch(year_months_sql, earliest_date).map(:year_month)
    puts @all_year_months
    @year_months = db.fetch(year_months_sql, @date).map(:year_month)
    puts @year_months
    @cats = categories_set
    puts @cats

    @cats.each do |cat|
        series = Hash.new
        data = db.fetch(costs_sql, cat, @date)#.map{|x| x[:amount].to_f}
        data_array = @year_months[0..11].dup
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

def get_one_year_ago
    return Date.strptime((Date.today.year - 1).to_s << '-' << Date.today.month.to_s, '%Y-%m')
end

def check_for_duplicates(data)
    data.each do |x|
        puts x
    end
    existing = Receipt.where(:date => data[:date], :amount => data[:amount], :item => data[:item])
    puts existing.all
    puts existing.all.length
    return (existing.all.length > 0)
end
