require 'haml'
require 'sinatra'
require 'sequel'
require 'sinatra/js'
require 'json'

set :haml, :format => :html5

db = Sequel.connect('postgres://localhost/budget')

categories_arr = db["select distinct items.expense from items join receipts on receipts.item = items.item where receipts.item like '1%' order by items.expense"].map(:expense)

year_months_sql = "select distinct to_char(date, 'YYYY-MM') as year_month from receipts where to_char(date, 'YYYY-MM')>= ? order by year_month asc"

costsSql = "select round(sum(amount), 2) as amount,
    date_part('month', date) as month
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
    seriesArray = []

    @year_months = db.fetch(year_months_sql, earliest_date).map(:year_month)
    @cats = categories_arr

    @cats.each do |cat|
        series = Hash.new
        data = db.fetch(costsSql, cat, earliest_date)#.map{|x| x[:amount].to_f}

        dataArr = Array.new(@year_months.length, 0)
        data.each do |x|
            index = x[:month]-1
            dataArr[index] = x[:amount].to_f
        end
        series['name'] = cat
        series['data'] = dataArr
        seriesArray.push(series)
    end

    @series = seriesArray.to_json
    puts @series
    haml :index
end

post '/' do
    puts params
    seriesArray = []

    @date = Date.strptime(params[:date], "%Y-%m")
    @year_months = db.fetch(year_months_sql, params[:date]).map(:year_month)
    @cats = categories_arr

    @cats.each do |cat|
        series = Hash.new
        data = db.fetch(costsSql, cat, @date)#.map{|x| x[:amount].to_f}

        dataArr = Array.new(@year_months.length, 0)
        data.each do |x|
            index = x[:month]-1
            dataArr[index] = x[:amount].to_f
        end
        series['name'] = cat
        series['data'] = dataArr
        seriesArray.push(series)
    end

    @series = seriesArray.to_json
    puts @series
    haml :index
end

