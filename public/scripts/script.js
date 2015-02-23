$(function(){

    //Receipt model - has date, amount, name, description, item, method, funding, expense, envelope, roommate, notes, tag and id columsn.

    window.Receipt = Backbone.Model.extend({
        idAttribute: "id",
        defaults:  {
            funding: 'General',
            expense: 'Personal'
        },
    });

    window.ReceiptList = Backbone.Collection.extend({
        model: Receipt,
        pageNumber:0,

        fetchNewItems: function () {
            this.pageNumber++;
            this.fetch({data: {page: this.pageNumber}});
        },
        fetchOnScroll: function(ev) {
            if ((window.innerHeight + window.scrollY) >=
                    document.body.offsetHeight) {
                this.fetchNewItems();
            }
        },
        attrFilter: function(attr, value) {
            filtered = this.filter(function(receipt) {
                return receipt.get(attr) === value;
            });
            filteredReceipts = new ReceiptList(filtered);

            $('table#items tbody.data').empty();
            filteredReceipts.each(function(receipt) {
                var filteredView = new ReceiptView({
                    model: receipt
                });
                this.$('table#items tbody.data').append(filteredView.render().el);
            });
        },

        comparator: function(m) {
            return -(new Date(m.get('date')));
        },

        url: '/api/receipts',

        funding: function() {
            return this.filter(function(receipt) {return receipt.get('funding');});
        }
    });


    window.Receipts = new ReceiptList;

    window.ReceiptView = Backbone.View.extend({
        tagName: 'tr',
        template: _.template($('#receipt-template').html()),
        initialize: function() {
            this.model.bind('change', this.render, this);
            this.model.bind('destroy', this.remove, this);
        },
        events: {
            "click td.delete" : "clear",
            "mouseenter td" : "showFilter",
            "mouseleave td" : "hideFilter",
            "click .filter" : "filter"
        },

        showFilter: function(ev) {
            $('span.filter', ev.target).addClass('show-filter');
        },
        hideFilter: function(ev) {
            $('span.filter', ev.target).removeClass('show-filter');
        },

        filter: function(ev) {
            var text = $.trim(ev.target.parentNode.textContent);
            var colName = ev.target.parentNode.className;
            Receipts.attrFilter(colName, text);
        },

        render: function() {
            $(this.el).html(this.template(this.model.toJSON()));
            this.setText();
            return this;
        },

        remove: function() {
            $(this.el).remove();
        },


        setText: function() {
            this.$('td.date').prepend(this.model.get('date'));
            this.$('td.amount').prepend(parseFloat(this.model.get('amount')));
            this.$('td.name').prepend(this.model.get('name'));
            this.$('td.description').prepend(this.model.get('description'));
            this.$('td.item').prepend(this.model.get('item'));
            this.$('td.method').prepend(this.model.get('method'));
            this.$('td.funding').prepend(this.model.get('funding'));
            this.$('td.expense').prepend(this.model.get('expense'));
            this.$('td.envelope').prepend(this.model.get('envelope'));
            this.$('td.roommate').prepend(this.model.get('roommate'));
            this.$('td.notes').prepend(this.model.get('notes'));
            this.$('td.tag').prepend(this.model.get('tag'));
        },

        clear: function() {
            this.model.destroy();
        }
    });


    window.AppView = Backbone.View.extend({
        el: $('#budgetApp'),
        initialize: function() {
            Receipts.bind('add', this.addOne, this);
            Receipts.bind('all', this.render, this);
            $(window).bind('scroll', function(ev) {
                Receipts.fetchOnScroll(ev)
            })
            Receipts.fetchNewItems();
        },

        events: {
            "submit form#new" : "createReceipt",
        },


        createReceipt: function(ev) {
            ev.preventDefault();
            var data = {};
            for (var i = 0, len = ev.target.length; i < len; i++) {
                var field = ev.target[i];
                if (field.value) {
                    data[field.name] = field.value;
                }
            }
            Receipts.create(data);
            ev.target.reset();
            return false;
        },


        addOne: function(receipt) {
            var view = new ReceiptView({model: receipt});
            this.$('table#items tbody.data').append(view.render().el);
        },
        addAll: function() {
            Receipts.each(this.addOne);
        }
    });
    window.App = new AppView;
});
