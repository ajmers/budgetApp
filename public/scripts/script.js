$(function(){

    //Receipt model - has date, amount, name, description, item, method, funding, expense, envelope, roommate, notes, tag and id columsn.

    window.Receipt = Backbone.Model.extend({
        idAttribute: "id",
        defaults: function() {
            return {
                funding: 'General',
                expense: 'Personal'
            };
        },
    });

    window.ReceiptList = Backbone.Collection.extend({
        model: Receipt,

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


        render: function() {
            $(this.el).html(this.template(this.model.toJSON()));
            this.setText();
            return this;
        },

        remove: function() {
            $(this.el).remove();
        },


        setText: function() {
            this.$('td.date').text(this.model.get('date'));
            this.$('td.amount').text(parseFloat(this.model.get('amount')));
            this.$('td.name').text(this.model.get('name'));
            this.$('td.description').text(this.model.get('description'));
            this.$('td.item').text(this.model.get('item'));
            this.$('td.method').text(this.model.get('method'));
            this.$('td.funding').text(this.model.get('funding'));
            this.$('td.expense').text(this.model.get('expense'));
            this.$('td.envelope').text(this.model.get('envelope'));
            this.$('td.roommate').text(this.model.get('roommate'));
            this.$('td.notes').text(this.model.get('notes'));
            this.$('td.tag').text(this.model.get('tag'));
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
            Receipts.fetch();
        },

        events: {
        //    "click td.delete" : "clear"
            "submit form#new" : "createReceipt"
        },

        createReceipt: function(ev) {
            ev.preventDefault();
            var data = {};
            for (var i = 0, len = ev.target.length; i < len; i++) {
                data[ev.target[i].name] = ev.target[i].value;
            }
            Receipts.create(data);
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
