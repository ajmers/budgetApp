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

columns = {
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

items_set = Receipt.order(Sequel.asc(:item)).distinct(:item)
#items_sql = "select distinct item from receipts order by item asc"

receipts_set = Receipt.order(Sequel.desc(:date))

categories_set = Item.order(Sequel.asc(:expense)).grep(:item, '1%').distinct(:expense).map(:expense)
#categories_arr = db["select distinct items.expense from items join receipts on receipts.item = items.item where receipts.item like '1%' order by items.expense"].map(:expense)

income_sql = "select round(sum(amount), 2) as amount,
    to_char(date, 'YYYY-MM') as month
    from receipts join items
    on receipts.item = items.item
    where items.expense = 'Primary income'
        and date >= ?
        and funding='General'
    group by items.expense, month
    order by month asc;"

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

earliest_date = Receipt.select(:date).order(:date).first[:date]

get '/receipts' do
    @columns = columns.dup
    @receipts= receipts_set.limit(100)
    @items = items_set.map(:item)

    haml :receipts
end

get '/receipts/new' do
    @columns = columns.dup
    @items = items_set.map(:item)

    haml :new_receipt
end



post '/receipts/new' do
    insert_params = {}

    Receipt.columns.each do |column|
        if params[column]
            insert_params[column] = params[column]
        end
    end

    already_exists = check_for_duplicates(insert_params)
    if not already_exists
        defaults.each do |key, value|
            sym = key.to_sym
            puts sym
            puts insert_params[sym].length
            if insert_params[sym].length == 0
                puts defaults[sym]
                insert_params[sym] = defaults[sym]
            else
                puts 'all necessary params present'
                puts sym.to_s << '-' << defaults[sym]
            end
        end
        puts insert_params
        new = Receipt.create(insert_params)
        redirect '/receipts'
    else
        puts 'already exists in db'
        redirect '/receipts'
    end
end



route :get, :post, '/' do
    cost_series_array = []
    income_series_array = []
    drilldown_array = []
    puts params

    if params[:date]
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
        #cost_series['drilldown'] = cat
        cost_series_array.push(cost_series)
    end

    income_data = db.fetch(income_sql, @date)
    month_array = @year_months[0..11].dup
    income_data_array = set_series_data(income_data, month_array)
    puts income_data_array

    @income_series = income_data_array
    @costs_series = cost_series_array.to_json
    puts @costs_series
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
    #data.each do |x|
    #    puts x
    #end
    existing = Receipt.where(:date => data[:date], :amount => data[:amount], :item => data[:item])
    #puts existing.all.length
    return (existing.all.length > 0)
end
