require 'haml'
require 'logger'
require 'sinatra'
require 'sequel'
require 'sinatra/js'
require 'json'
require 'sinatra/contrib'

set :haml, :format => :html5

db = Sequel.connect('postgres://localhost/budget')
db.extension(:pagination)
db.loggers << Logger.new($stdout)
class Item < Sequel::Model; end
class Receipt < Sequel::Model; end
class Sequel::Dataset
    def to_json
        naked.all.to_json
    end
end

defaults = {:funding => 'General', :expense => 'Personal' }

receipt_columns = {
   :date=> {:type => 'date', :display => 'show'},
   :amount=> {:type => 'number', :display => 'show'},
   :name=> {:type => 'text', :display => 'show'},
   :description=> {:type => 'text', :display => 'hide'},
   :item=> {:type => 'select', :display => 'show'},
   :method=> {:type => 'text', :display => 'show'},
   :funding=> {:type => 'text', :display => 'hide'},
   :expense=> {:type => 'text', :display => 'hide'},
   :envelope=> {:type => 'text', :display => 'hide'},
   :roommate=> {:type => 'text', :display => 'hide'},
   :notes=> {:type => 'text', :display => 'hide'},
   :tag=> {:type => 'text', :display => 'hide'}
}

item_columns = {
    :item => {:type => 'text', :display => 'show'},
    :category => {:type => 'text', :display => 'show'},
    :recurring => {:type => 'text', :display => 'show'},
    :order => {:type => 'text', :display => 'show'},
}

items_set = Item.order(Sequel.asc(:item)).distinct(:item)
#items_sql = "select distinct item from receipts order by item asc"

receipts_set = Receipt.order(Sequel.desc(:date))

categories_set = Item.distinct(:category, :order).grep(:item, '1%').order(Sequel.desc(:order)).map(:category)

income_cats_set = Item.distinct(:category, :order).grep(:item, '2%').order(Sequel.desc(:order)).map(:category)

methods_set = Receipt.order(Sequel.asc(:method)).distinct(:method).select(:method).map(:method)

year_months_sql = "select distinct to_char(date, 'YYYY-MM') as year_month
    from receipts
    where date >= ?
    order by year_month asc"

income_sql = "select round(sum(amount), 2) as amount,
    to_char(date, 'YYYY-MM') as month
    from receipts join items
    on receipts.item = items.item
    where items.category = 'Primary income'
        and date >= ?
        and funding='General'
    group by items.category, month
    order by month asc;"

costs_sql = "select round(sum(amount), 2) as amount,
    to_char(date, 'YYYY-MM') as month
    from receipts join items
    on receipts.item = items.item
    where items.category = ?
        and date >= ?
        and funding = 'General'
    group by items.category, month, items.order
    order by items.order desc limit 12"

subcategory_costs_sql = "select round(sum(amount), 2) as amount,
    to_char(date, 'YYYY-MM') as month
    where item = ?
        and date >= ?
        and funding = 'General'
    group by item, month
    order by item desc"

earliest_date = Receipt.select(:date).order(:date).first[:date]


get '/receipts' do
    @id = 'new_receipt'
    @action = '/receipts/new'
    @columns = receipt_columns.dup
    @receipts= receipts_set.limit(100)
    @items = items_set.map(:item)
    @methods = methods_set

    haml :receipts
end

get '/receipts/new' do
    @id = 'new_receipt'
    @action = '/receipts/new'
    @columns = receipt_columns.dup
    @items = items_set.map(:item)
    @methods = methods_set

    haml :new_receipt
end


get '/items' do
    @columns = item_columns.dup
    @items = items_set.map(:item)
    @action = '/items/new'
    haml :items
end

get '/items/new' do
    @columns = item_columns.dup
    @items = items_set.map(:item)
    @action = '/items/new'
    haml :form
end

route :get, :post, '/' do
    cost_series_array = []
    drilldown_array = []

    if params[:date]
        puts params[:date]
        @date = Date.strptime(params[:date], "%Y-%m")
        puts @date
    else
        @date = get_one_year_ago()
        puts @date
    end

    @all_year_months = db.fetch(year_months_sql, earliest_date).map(:year_month)
    @year_months = db.fetch(year_months_sql, @date).map(:year_month)
    @cats = categories_set

    @cats.each do |cat|
        cost_series = Hash.new
        data = db.fetch(costs_sql, cat, @date)#.map{|x| x[:amount].to_f}
        puts data.all
        data_array = @year_months[0..11].dup
        cost_series_data = set_series_data(data, data_array)

        cost_series['name'] = cat
        cost_series['data'] = cost_series_data
        cost_series['stack'] = 'cost'
        #cost_series['drilldown'] = cat
        cost_series_array.push(cost_series)
    end

    @costs_series = cost_series_array.to_json
    haml :index
end


# API routes

get '/api/receipts/:id' do
    receipt = Receipt[:id]
    return receipt.values.to_json
end

delete '/api/receipts/:id' do
    puts :id
    receipt = Receipt[params[:id]]
    if receipt
        receipt.delete
    end
end

patch '/api/receipts/:id' do
    puts :id

    insert_params = {}
    request_payload = JSON.parse request.body.read
    puts request_payload
    request_payload.delete('submit')
    request_payload.delete('id')

    record = Receipt[params[:id]]
    record.update(request_payload)
    record.save_changes

    return record.values.to_json

end

get '/api/income/:date' do
    if params[:date]
        date = Date.strptime(params[:date], "%Y-%m")
        puts date
    else
        date = get_one_year_ago()
    end

    @year_months = db.fetch(year_months_sql, date).map(:year_month)
    puts @year_months

    income_series = Hash.new
    data = db.fetch(income_sql, date)#.map{|x| x[:amount].to_f}
    puts data.all
    data_array = @year_months[0..11].dup
    puts data_array
    income_series_data = set_series_data(data, data_array)
    puts income_series_data

    income_series['name'] = 'Primary income'
    income_series['data'] = income_series_data
    income_series['stack'] = 'income'
    #cost_series['drilldown'] = cat

    return income_series.to_json
end


get '/api/receipts' do
    allowed_filters = ["item", "method", "name"]

    page = params[:page].blank?? 1 : Integer(params[:page])
    puts page
    filters = params[:filters].blank?? Hash.new : params[:filters].select { |i| allowed_filters.include?(i) }
    filters = Hash[filters.map{|(k,v)| [k.to_sym,v]}]
    puts filters
    results = receipts_set.paginate(page, 50)

    filters.each do |key, value|
        results = results.where("#{key} = ?", value)
    end

    return results.to_json
end

def get_page_range(page)
    at_a_time = 50
    return page * at_a_time
end


get '/api/receipts/new' do
    @id = 'new_receipt'
    @action = '/receipts/new'
    @columns = columns.dup
    @items = items_set.map(:item)
    @methods = methods_set

    haml :new_receipt
end


post '/api/receipts' do
    insert_params = {}
    request_payload = JSON.parse request.body.read
    puts request_payload
    request_payload.delete('submit')
    request_payload.delete('new')

    already_exists = check_for_duplicates(request_payload)
    if not already_exists
        new = Receipt.create(request_payload)
        puts new
        redirect '/receipts'
    else
        puts 'already exists in db'
        redirect '/receipts'
    end
end

get '/api/methods' do
    @methods = methods_set
    return @methods.to_json
end

get '/api/items' do
    @items = Item.order(:item)
    return @items.to_json
end

get '/api/items/:id' do
    @item = Item[:id]
    return @item.values.to_json
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
    puts data_array
    return data_array
end


def get_one_year_ago
    return Date.strptime((Date.today.year - 1).to_s << '-' << (Date.today.month + 1).to_s, '%Y-%m')
end

def check_for_duplicates(data)
    #data.each do |x|
    #    puts x
    #end
    existing = Receipt.where(:date => data[:date], :amount => data[:amount], :item => data[:item])
    puts existing.all.length
    return (existing.all.length > 0)
end
