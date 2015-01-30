require 'haml'
require 'sinatra'
require 'sequel'
require 'sinatra/js'
require 'json'

set :haml, :format => :html5

db = Sequel.connect('postgres://localhost/budget')

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
    order by items.order desc"

earliest_date = Date.strptime("2010-07", "%Y-%m")

get '/' do
    puts params
    series_array = []

    @year_months = db.fetch(year_months_sql, earliest_date).map(:year_month)
    @cats = categories_arr

    @cats.each do |cat|
        series = Hash.new
        data = db.fetch(costs_sql, cat, earliest_date)#.map{|x| x[:amount].to_f}

        data_array = Array.new
        index = 0
        data.each do |x|
            puts index
            puts x
            puts x[:month]
            puts @year_months[index]

            until x[:month] <= @year_months[index] do
                puts 'nothing for this month, pushing 0'
                data_array.push(0)
                index += 1
            end

            if x[:month] == @year_months[index]
                puts 'pushing amount'
                data_array.push(x[:amount].to_f)
                index += 1
            else
                puts 'pushing 0'
                data_array.push(0)
            end

        end
        series['name'] = cat
        series['data'] = data_array
        series_array.push(series)
    end

    @series = series_array.to_json
    haml :index
end

post '/' do
    puts params
    series_array = []

    @date = Date.strptime(params[:date], "%Y-%m")
    puts @date

    @year_months = db.fetch(year_months_sql, params[:date]).map(:year_month)
    puts @year_months
    puts @year_months.length
    @cats = categories_arr
    puts @cats

    @cats.each do |cat|
        series = Hash.new
        data = db.fetch(costs_sql, cat, @date)#.map{|x| x[:amount].to_f}
        puts data

        data_array = Array.new
        index = 0
        data.each do |x|
            puts index
            puts x
            puts x[:month]
            puts @year_months[index]

            until x[:month] <= @year_months[index] do
                puts 'nothing for this month, pushing 0'
                data_array.push(0)
                index += 1
            end

            if x[:month] == @year_months[index]
                puts 'pushing amount'
                data_array.push(x[:amount].to_f)
                index += 1
            else
                puts 'pushing 0'
                data_array.push(0)
            end

            if data_array.length >= 12
                break
            end
        end
        series['name'] = cat
        series['data'] = data_array
        puts series
        series_array.push(series)
    end

    @series = series_array.to_json
    haml :index
end

